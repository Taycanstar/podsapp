////
////  HomePodView.swift
////  Pods
////
////  Created by Dimi Nunez on 2/2/25.
////
import SwiftUI
import AVFoundation
import Mixpanel

struct HomePodView: View {
    // Bindings provided from the parent view
    @Binding var pod: Pod
    @Binding var needsRefresh: Bool

    // Environment values and objects
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.isTabBarVisible) var isTabBarVisible

    // Local states
    @State private var isEditing = false
    @State private var isActivityOpen = false
    @State private var reorderedItems: [PodItem] = []
    @State private var deletedItemIDs: [Int] = []
    @State private var showMenu = false
    @State private var isAnyItemEditing = false
    @State private var showDoneButton = false
    @State private var editingItemId: Int?
    @State private var selection: (podIndex: Int, itemIndex: Int)?

    // For focusing text fields, etc.
    @FocusState private var focusedField: String?
    @State private var showNotesPlaceholder: [Int: Bool] = [:]
    @State private var showPodOptionsSheet = false

    // For new item creation
    @State private var isCreatingNewItem = false
    @State private var newItemText = ""
    @FocusState private var isNewItemFocused: Bool

    // View mode selector
    enum ViewType: String, CaseIterable {
        case list = "List"
        case table = "Table"
        case calendar = "Calendar"
    }
    @State private var selectedView: ViewType = .list

    // Keyboard offset state
    @State private var keyboardOffset: CGFloat = 0

    // Column editing and card sheet states
    @State private var selectedColumnForEdit: (index: Int, name: String)?
    @State private var showColumnEditSheet = false
    @State private var showCardSheet = false
    @State private var showLogActivitySheet = false
    @State private var selectedItemIndex: Int?

    // Pod columns and visibility
    @State private var podColumns: [PodColumn]
    @State private var showPodColumnsView = false
    @State private var visibleColumns: [String] = []

    // Other states
    @State private var navigateToPodInfo = false
    @State private var navigateToPodMembers = false
    @State private var refreshID = UUID()
    @State private var forceUpdate = false
    @State private var currentTitle: String
    @State private var currentDescription: String
    @State private var currentInstructions: String
    @State private var currentType: String
    @State private var itemsWithRecentActivity: Set<Int> = Set()
    @State private var navigateToActivityLog = false

    // For media
    @State private var selectedItemForMedia: PodItem?
    @State private var showCameraView = false

    // Loading and network state
    @State private var isAddInputLoading = false
    @StateObject private var videoPreloader = VideoPreloader()
    @State private var isLoading = true

    // Managers and activity states
    @StateObject private var logManager = ActivityLogManager()
    @StateObject private var activityManager = ActivityManager()
    @ObservedObject private var activityState = ActivityState.shared
    @State private var showCountdown = false
    var networkManager: NetworkManager = NetworkManager()


    // Initializer – note that HomePodView takes a binding to a Pod and a binding to a Bool.
    init(pod: Binding<Pod>, needsRefresh: Binding<Bool>) {
        self._pod = pod
        self._needsRefresh = needsRefresh
        // Capture initial pod details for local state
        self._podColumns = State(initialValue: pod.wrappedValue.columns)
        self._visibleColumns = State(initialValue: pod.wrappedValue.visibleColumns)
        self._currentTitle = State(initialValue: pod.wrappedValue.title)
        self._currentDescription = State(initialValue: pod.wrappedValue.description ?? "")
        self._currentInstructions = State(initialValue: pod.wrappedValue.instructions ?? "")
        self._currentType = State(initialValue: pod.wrappedValue.type ?? "")
    }

    // Determine if pod has complete data
    private var hasCompleteData: Bool {
        return !pod.columns.isEmpty && !pod.items.isEmpty
    }

    var body: some View {
        ZStack {
            Color("bg")
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        Spacer()
                    }
                } else {
                    VStack(spacing: 12) {
                        listView
                    }
                    .safeAreaInset(edge: .bottom) {
                        if !isCreatingNewItem && !activityState.isActivityInProgress {
                            footerView
                        }
                    }
                    .padding(.bottom, keyboardOffset)
                }
            }
        }
        .navigationTitle(pod.title)
        .navigationBarTitleDisplayMode(.inline)
        .edgesIgnoringSafeArea(.bottom)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showPodOptionsSheet = true
                }) {
                          ZStack {
                        Circle()
                            .fill(Color(UIColor.secondarySystemFill))
                            .frame(width: 30, height: 30)
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .onAppear {
            self.reorderedItems = self.pod.items
            uploadViewModel.addItemCompletion = {
                refreshPodItems()
            }
            homeViewModel.updatePodLastVisited(podId: pod.id)
            isTabBarVisible.wrappedValue = false
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                if let keyboardSize = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation {
                        keyboardOffset = keyboardSize.height
                    }
                }
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                withAnimation {
                    keyboardOffset = 0
                }
            }
            if !hasCompleteData {
                fetchFullPodDetails(showLoadingIndicator: true)
            } else {
                isLoading = false
            }
            initializeManagers()
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                fetchFullPodDetails(showLoadingIndicator: false)
            }
        }
        .onDisappear {
            isTabBarVisible.wrappedValue = true
            
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        // Attach all sheets and full-screen covers as before.
        .sheet(isPresented: $showPodOptionsSheet) {
            PodOptionsView(
                showPodOptionsSheet: $showPodOptionsSheet,
                showPodColumnsView: $showPodColumnsView,
                onDeletePod: deletePod,
                podName: pod.title,
                podId: pod.id,
                navigationAction: { destination in
                    showPodOptionsSheet = false
                    let wasActivityOpen = isActivityOpen
                    isActivityOpen = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Insert navigation logic here if needed.
                    }
                }
            )
        }
        .sheet(isPresented: $isActivityOpen) {
            ActivityView(
                pod: $pod,
                podColumns: $podColumns,
                items: $reorderedItems,
                onActivityFinished: { duration, startTime, endTime, notes in
                    // Handle activity finish – insert navigation or summary logic here.
                }
            )
            .presentationDetents([.height(50), .large], selection: $activityState.sheetHeight)
            .interactiveDismissDisabled(activityState.isActivityInProgress)
            .presentationBackgroundInteraction(.enabled)
            .onChange(of: activityState.sheetHeight) { newHeight in
                if !activityState.isActivityInProgress {
                    activityState.sheetHeight = .large
                }
            }
        }
        .sheet(isPresented: $showPodColumnsView) {
            PodColumnsView(
                podColumns: $podColumns,
                isPresented: $showPodColumnsView,
                podId: pod.id,
                networkManager: networkManager,
                visibleColumns: $visibleColumns
            )
            .onDisappear {
                fetchFullPodDetails(showLoadingIndicator: false)
            }
        }
        .fullScreenCover(isPresented: $showCameraView) {
            if let selectedItem = selectedItemForMedia {
                CameraView(
                    showingVideoCreationScreen: $showCameraView,
                    selectedTab: .constant(0),
                    podId: pod.id,
                    itemId: selectedItem.id
                ) { updatedItemId in
                    refreshItem(with: updatedItemId)
                }
            }
        }
        .fullScreenCover(isPresented: $showCountdown) {
            ActivityCountdownView(isPresented: $showCountdown) {
                activityState.sheetHeight = .large
                isActivityOpen = true
            }
        }
        .sheet(isPresented: $showColumnEditSheet) {
            if let selectedColumn = selectedColumnForEdit,
               let itemIndex = selectedItemIndex,
               itemIndex < reorderedItems.count,
               selectedColumn.index < podColumns.count {
                let item = reorderedItems[itemIndex]
                let column = podColumns[selectedColumn.index]
                ColumnEditView(
                    itemId: item.id,
                    columnName: column.name,
                    columnType: column.type,
                    value: Binding(
                        get: { item.columnValues?[column.name] ?? .null },
                        set: { newValue in
                            updateColumnValue(itemIndex: itemIndex, columnName: column.name, newValue: newValue)
                        }
                    ),
                    onSave: { _ in },
                    networkManager: networkManager,
                    onViewTrendsTapped: { }
                )
                .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
            }
        }
        .onChange(of: showColumnEditSheet) { newValue in
            if !newValue {
                // Handle any pending navigation if needed.
            }
        }
        .sheet(isPresented: $showCardSheet) {
            if let index = selectedItemIndex {
                CardDetailView(
                    item: Binding<PodItem>(
                        get: { self.reorderedItems[index] },
                        set: { self.reorderedItems[index] = $0 }
                    ),
                    podId: pod.id,
                    podTitle: pod.title,
                    podColumns: $podColumns,
                    networkManager: networkManager,
                    allItems: Binding<[PodItem]>(
                        get: { self.reorderedItems },
                        set: { self.reorderedItems = $0 }
                    ),
                    visibleColumns: $visibleColumns
                )
                .id(reorderedItems[index].notes)
                .onDisappear {
                    if activityState.isActivityInProgress {
                        isActivityOpen = true
                    }
                }
            }
        }
        .sheet(isPresented: $showLogActivitySheet) {
            if let index = selectedItemIndex {
                LogActivityView(
                    item: reorderedItems[index],
                    podColumns: podColumns,
                    podId: pod.id,
                    logManager: logManager,
                    onActivityLogged: { newLog in
                        onActivityLogged(newLog: newLog)
                    }
                )
                .onDisappear {
                    if activityState.isActivityInProgress {
                        isActivityOpen = true
                    }
                }
            }
        }
    }
    
    // MARK: - Footer View

    private var footerView: some View {
        HStack {
            Button(action: {
                isCreatingNewItem = true
                isNewItemFocused = true
                HapticFeedback.generate()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                    Text("New Item")
                        .font(.system(size: 18))
                        .fontWeight(.medium)
                        .fontDesign(.rounded)
                }
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
            Spacer()
            Button(action: {
                showCountdown = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 24))
                        .fontWeight(.medium)
                        .foregroundColor(Color("iosred"))
                    Text("Record Activity")
                        .font(.system(size: 18))
                        .fontWeight(.medium)
                        .fontDesign(.rounded)
                        .foregroundColor(Color("iosred"))
                }
                .foregroundColor(.accentColor)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 36)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .top
        )
    }
    
    // MARK: - Helper Functions
    
    private func initializeManagers() {
        activityManager.initialize(podId: pod.id, userEmail: viewModel.email)
    }
    
    private func fetchFullPodDetails(showLoadingIndicator: Bool = true) {
        if showLoadingIndicator { isLoading = true }
        networkManager.fetchFullPodDetails(email: viewModel.email, podId: pod.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fullPod):
                    self.pod = fullPod
                    self.reorderedItems = fullPod.items
                    self.podColumns = fullPod.columns
                    self.visibleColumns = fullPod.visibleColumns
                    self.currentTitle = fullPod.title
                    self.currentDescription = fullPod.description ?? ""
                    self.currentInstructions = fullPod.instructions ?? ""
                    self.currentType = fullPod.type ?? ""
                case .failure(let error):
                    print("Failed to load pod details: \(error.localizedDescription)")
                }
                if showLoadingIndicator { isLoading = false }
            }
        }
    }
    
    private func refreshItem(with id: Int) {
        networkManager.fetchPodItem(podId: pod.id, itemId: id, userEmail: viewModel.email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedItem):
                    if let index = reorderedItems.firstIndex(where: { $0.id == id }) {
                        reorderedItems[index] = updatedItem
                    }
                    pod.items = reorderedItems
                    needsRefresh = true
                case .failure(let error):
                    print("Failed to fetch updated item: \(error)")
                }
            }
        }
    }
    
    private func onActivityLogged(newLog: PodItemActivityLog) {
        showTemporaryCheckmark(for: newLog.itemId)
        if let itemIndex = self.reorderedItems.firstIndex(where: { $0.id == newLog.itemId }) {
            if self.reorderedItems[itemIndex].columnValues == nil {
                self.reorderedItems[itemIndex].columnValues = [:]
            }
            for (key, value) in newLog.columnValues {
                self.reorderedItems[itemIndex].columnValues?[key] = value
            }
            if let podItemIndex = self.pod.items.firstIndex(where: { $0.id == newLog.itemId }) {
                self.pod.items[podItemIndex].columnValues = self.reorderedItems[itemIndex].columnValues
            }
        }
    }
    
    private func showTemporaryCheckmark(for itemId: Int) {
        withAnimation { _ = itemsWithRecentActivity.insert(itemId) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { _ = self.itemsWithRecentActivity.remove(itemId) }
        }
    }
    
    private func updateColumnValue(itemIndex: Int, columnName: String, newValue: ColumnValue) {
        guard itemIndex < reorderedItems.count else { return }
        if reorderedItems[itemIndex].columnValues == nil {
            reorderedItems[itemIndex].columnValues = [:]
        }
        reorderedItems[itemIndex].columnValues?[columnName] = newValue
        pod.items = reorderedItems
        needsRefresh = true
    }
    
    private func refreshPodItems() {
        isLoading = true
        DispatchQueue.global(qos: .background).async {
            networkManager.fetchItemsForPod(podId: pod.id) { items, error in
                DispatchQueue.main.async {
                    if let items = items {
                        self.reorderedItems = items
                        self.pod.items = items
                    } else {
                        print("Failed to fetch items for pod: \(error ?? "Unknown error")")
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private func moveItem(from source: IndexSet, to destination: Int) {
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
    
    private func deletePod() {
        networkManager.deletePod(podId: pod.id) { success, message in
            DispatchQueue.main.async {
                if success {
                    print("Pod deleted successfully.")
                    if let index = homeViewModel.pods.firstIndex(where: { $0.id == pod.id }) {
                        homeViewModel.pods.remove(at: index)
                    }
                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("Failed to delete pod: \(message ?? "Unknown error")")
                }
            }
        }
    }
    
    private func deleteItem(at offsets: IndexSet) {
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
    
    private var listView: some View {
        List {
            ForEach(reorderedItems.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reorderedItems[index].metadata)
                            .font(.system(size: 14))
                            .fontWeight(.regular)
                        HStack {
                            ForEach(podColumns.filter { visibleColumns.contains($0.name) }, id: \.name) { column in
                                columnView(name: column.name, item: reorderedItems[index])
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.leading, 10)
                    Spacer()
                    VStack {
                        Spacer()
                        if itemsWithRecentActivity.contains(reorderedItems[index].id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                                .transition(.opacity)
                        } else {
                            iconView(for: reorderedItems[index], index: index)
                        }
                        Spacer()
                    }
                }
                .background(Color("bg"))
                .cornerRadius(10)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        let indexSet = IndexSet([index])
                        deleteItem(at: indexSet)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 15, bottom: 6, trailing: 15))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedItemIndex = index
                    showCardSheet = true
                    let wasActivityOpen = isActivityOpen
                    isActivityOpen = false
                    HapticFeedback.generate()
                }
            }
            if isCreatingNewItem {
                newItemInputView
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color("bg"))
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            fetchFullPodDetails(showLoadingIndicator: false)
        }
        .background(Color("bg"))
    }
    
    private func iconView(for item: PodItem, index: Int) -> some View {
        Menu {
            if item.videoURL != nil || item.imageURL != nil {
                Button(action: {
                    // Use your parent navigation logic to push a player view.
                }) {
                    Label("Play Video", systemImage: "play.circle")
                }
                Button(action: {
                    selectedItemForMedia = item
                    showCameraView = true
                }) {
                    Label("Change Video", systemImage: "video.badge.plus")
                }
            } else {
                Button(action: {
                    selectedItemForMedia = item
                    showCameraView = true
                }) {
                    Label("Add Video", systemImage: "video.badge.plus")
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
                Image(systemName: "ellipsis")
                    .font(.system(size: 15))
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private func columnView(name: String, item: PodItem) -> some View {
        let column = podColumns.first { $0.name == name }
        let value = item.columnValues?[String(column?.id ?? 0)] ?? .null
        let displayValue: ColumnValue = {
            if case .array(let values) = value, !values.isEmpty {
                return values[0]
            }
            return value
        }()
        return VStack(spacing: 0) {
            Text("\(displayValue) \(column?.name ?? name)")
                .font(.system(size: 13))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .cornerRadius(4)
        .background(Color("iosbtn"))
        .cornerRadius(4)
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 44, 44, 44) : Color(rgb: 230, 230, 230)
    }
    
    private var newItemInputView: some View {
        HStack {
            TextField("Add Item", text: $newItemText)
                .id("NewItemTextField")
                .font(.system(size: 14))
                .padding(.vertical, 8)
                .padding(.horizontal, 5)
                .background(Color("iosnp"))
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
                if isAddInputLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    Text("Add")
                        .fontWeight(.regular)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            .disabled(newItemText.isEmpty)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 5)
        .background(Color("iosnp"))
        .cornerRadius(12)
        .padding(.horizontal, 15)
        .padding(.bottom, 20)
        .padding(.top, 10)
    }
    
    private func createNewPodItem() {
        isAddInputLoading = true
        let newItemColumnValues: [String: ColumnValue] = pod.columns.reduce(into: [:]) { result, column in
            switch column.type {
            case "number":
                result[column.name] = .number(0)
            case "time":
                result[column.name] = .time(TimeValue(hours: 0, minutes: 0, seconds: 0))
            case "text":
                result[column.name] = .string("")
            default:
                result[column.name] = .null
            }
        }
        networkManager.createPodItem(
            podId: pod.id,
            label: newItemText,
            itemType: nil,
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
                    self.isAddInputLoading = false
                case .failure(let error):
                    print("Failed to create new pod item: \(error)")
                    self.isAddInputLoading = false
                }
            }
        }
    }
    

}
