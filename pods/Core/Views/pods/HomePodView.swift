

import SwiftUI
import AVFoundation
import Mixpanel

// MARK: - HomePodView

struct HomePodView: View {
    // Instead of receiving an entire Pod, we receive only its id.
    let podId: Int
    @Binding var needsRefresh: Bool

    // Environment objects – note that we inject PodsViewModel so that this view always uses the global data.
    @EnvironmentObject var podsViewModel: PodsViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isTabBarVisible) var isTabBarVisible

    // Local state variables
    @State private var isActivityOpen: Bool = false
    @State private var reorderedItems: [PodItem] = []
    @State private var isCreatingNewItem: Bool = false
    @State private var newItemText: String = ""
    @FocusState private var isNewItemFocused: Bool  // Do not initialize FocusState

    // Sheet/option states
    @State private var showPodOptionsSheet: Bool = false
    @State private var showCardSheet: Bool = false
    @State private var showLogActivitySheet: Bool = false
    @State private var showPodColumnsView: Bool = false

    // For editing columns (if needed)
    @State private var selectedColumnForEdit: (index: Int, name: String)?
    @State private var selectedItemIndex: Int?

    // Keyboard offset
    @State private var keyboardOffset: CGFloat = 0

    // Pod columns and visible columns
    @State private var podColumns: [PodColumn] = []
    @State private var visibleColumns: [String] = []

    // Other display state
    @State private var currentTitle: String = ""
    @State private var currentDescription: String = ""
    @State private var currentInstructions: String = ""
    @State private var currentType: String = ""
    @State private var itemsWithRecentActivity: Set<Int> = Set()

    // For media
    @State private var selectedItemForMedia: PodItem?
    @State private var showCameraView: Bool = false

    // Loading state
    @State private var isAddInputLoading: Bool = false
    @State private var isLoading: Bool = true

    // Managers
    @StateObject private var videoPreloader = VideoPreloader()
    @StateObject private var logManager = ActivityLogManager()
    @StateObject private var activityManager = ActivityManager()
    @ObservedObject private var activityState = ActivityState.shared
    @State private var showCountdown: Bool = false
    @Binding var navigationPath: NavigationPath

    var networkManager: NetworkManager = NetworkManager()

    // MARK: - Computed Properties

    /// Lookup the full pod from the global PodsViewModel.
    var pod: Pod? {
        podsViewModel.pods.first(where: { $0.id == podId })
    }
    

    
    // MARK: - Body

    var body: some View {
        Group {
            if let pod = pod {
                if isLoading {
                    // Show loader if data is missing.
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        Spacer()
                    }
                    .onAppear {
                        fetchFullPodDetails(showLoadingIndicator: true)
                    }
                } else {
                    // Data is complete – display the list view.
                    VStack(spacing: 0) {
                        listView
                    }
                    .safeAreaInset(edge: .bottom) {
                        if !isCreatingNewItem && !activityState.isActivityInProgress {
                                           footerView
                                       }
                    }
//                    .padding(.bottom, keyboardOffset)
                }
            } else {
                Text("Pod not found")
            }
        }
        .navigationTitle(pod?.title ?? "Pod Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showPodOptionsSheet = true }) {
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
            isTabBarVisible.wrappedValue = false
            if let pod = pod {
                // Update local state from the global pod.
                self.reorderedItems = pod.items
                self.podColumns = pod.columns
                self.visibleColumns = pod.visibleColumns
                self.currentTitle = pod.title
                self.currentDescription = pod.description ?? ""
                self.currentInstructions = pod.instructions ?? ""
                self.currentType = pod.type ?? ""
            }
            // Setup keyboard notifications.
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                if let keyboardSize = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation { keyboardOffset = keyboardSize.height }
                }
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                withAnimation { keyboardOffset = 0 }
            }
            
            podsViewModel.updatePodVisited(podId: podId)
            
            initializeManagers()
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                fetchFullPodDetails(showLoadingIndicator: false)
            }
        }
        .onDisappear {
//            isTabBarVisible.wrappedValue = true
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        // Attach sheets.
        .sheet(isPresented: $showPodOptionsSheet) {
            PodOptionsView(
                showPodOptionsSheet: $showPodOptionsSheet,
                showPodColumnsView: $showPodColumnsView,
                onDeletePod: { deletePod() },
                podName: pod?.title ?? "",
                podId: pod?.id ?? 0,
                navigationAction: { destination in
                            showPodOptionsSheet = false
                    let wasActivityOpen = isActivityOpen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        navigationPath.append(destination)
                        if wasActivityOpen {
                                       isActivityOpen = true
                                   }
                    }
                        },
                podColumns: podColumns
            )
        }
        .sheet(isPresented: $showPodColumnsView) {
            PodColumnsView(
                podColumns: $podColumns,
                isPresented: $showPodColumnsView,
                podId: podId,
                networkManager: networkManager,
                visibleColumns: $visibleColumns
            )
            .onDisappear {
                fetchFullPodDetails(showLoadingIndicator: false)
            }
        }
        .sheet(isPresented: $isActivityOpen) {
            if let podIndex = podsViewModel.pods.firstIndex(where: { $0.id == podId }) {
                ActivityView(
                    pod: Binding(
                        get: { self.podsViewModel.pods[podIndex] },
                        set: { self.podsViewModel.pods[podIndex] = $0 }
                    ),
                    podColumns: $podColumns,
                    items: $reorderedItems,
                    onActivityFinished: { duration, startTime, endTime, notes in
                        navigationPath.append(AppNavigationDestination.activitySummary(
                            podId: podId,
                            duration: duration,
                            startTime: startTime,
                            endTime: endTime,
                            podColumns: podColumns,
                            notes: notes
                        ))
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
        }
        .fullScreenCover(isPresented: $showCameraView) {
                   if let selectedItem = selectedItemForMedia {
                       CameraView(
                           showingVideoCreationScreen: $showCameraView,
                           selectedTab: .constant(0),
                           podId: podId,
                           itemId: selectedItem.id
                       ) { updatedItemId in
                           refreshItem(with: updatedItemId)
                       }
                   }
               }
            
        .fullScreenCover(isPresented: $showCountdown) {
            ActivityCountdownView(isPresented: $showCountdown) {
                // This closure is called when countdown finishes
                activityState.sheetHeight = .large
                isActivityOpen = true
            }
        }
    }
    
    // MARK: - List View
    
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
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedItemIndex = index
                    showCardSheet = true
                    HapticFeedback.generate()
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 15, bottom: 6, trailing: 15))
                .listRowBackground(Color("bg"))
            }
            
            if isCreatingNewItem {
                HStack(alignment: .top, spacing: 0) {
                    TextField("Add Item", text: $newItemText)
                        .id("NewItemTextField")
                        .font(.system(size: 14))
                        .fontWeight(.regular)
                        .focused($isNewItemFocused)
                        .onSubmit {
                            if !newItemText.isEmpty {
                                createNewPodItem()
                            }
                        }
                    
                    Spacer()
                    
                    if isAddInputLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Button(action: {
                            if !newItemText.isEmpty {
                                createNewPodItem()
                            }
                        }) {
                            Text("Add")
                                .fontWeight(.regular)
                                .font(.system(size: 14))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .disabled(newItemText.isEmpty)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .listRowInsets(EdgeInsets(top: 6, leading: 15, bottom: 6, trailing: 15))
                .listRowBackground(Color("bg"))
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            fetchFullPodDetails(showLoadingIndicator: false)
        }
    }
    
    private func iconView(for item: PodItem, index: Int) -> some View {
        Menu {
            if item.videoURL != nil || item.imageURL != nil {
                Button(action: {
                    navigationPath.append(AppNavigationDestination.player(item: item))
                    let wasActivityOpen = isActivityOpen
                    isActivityOpen = false
                }) {
                    Label("Play Video", systemImage: "play.circle")
                }
                
                Button(action: {
                    selectedItemForMedia = item
                    showCameraView = true
                }) {
                    Label("Change Media", systemImage: "video.badge.plus")
                }
            } else {
                Button(action: {
                    selectedItemForMedia = item
                    showCameraView = true
                }) {
                    Label("Add Media", systemImage: "video.badge.plus")
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
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .top
        )
    }
    
    
    // MARK: - Column View
    
    private func columnView(name: String, item: PodItem) -> some View {
        // Look up the column by name in podColumns.
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
        .background(Color("iosbtn"))
        .cornerRadius(4)
    }
    
    // MARK: - Helper Functions
    
    private func initializeManagers() {
        activityManager.initialize(podId: pod?.id ?? 0, userEmail: viewModel.email)
    }
    
    private func fetchFullPodDetails(showLoadingIndicator: Bool = true) {
        guard let currentPod = pod else { return }


        if showLoadingIndicator { isLoading = true }
        networkManager.fetchFullPodDetails(email: viewModel.email, podId: currentPod.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fullPod):
                    if let index = podsViewModel.pods.firstIndex(where: { $0.id == fullPod.id }) {
                        podsViewModel.pods[index] = fullPod
                    }
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

    
    private func deletePod() {
        guard let currentPod = pod else { return }
        networkManager.deletePod(podId: currentPod.id) { success, message in
            DispatchQueue.main.async {
                if success {
                    if let index = podsViewModel.pods.firstIndex(where: { $0.id == currentPod.id }) {
                        podsViewModel.pods.remove(at: index)
                    }
                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("Failed to delete pod: \(message ?? "Unknown error")")
                }
            }
        }
    }
    
    private func createNewPodItem() {
        guard let currentPod = pod else { return }
        isAddInputLoading = true
        let newItemColumnValues: [String: ColumnValue] = currentPod.columns.reduce(into: [:]) { result, column in
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
            podId: currentPod.id,
            label: newItemText,
            itemType: nil,
            notes: "",
            columnValues: newItemColumnValues
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newItem):
                    self.reorderedItems.append(newItem)
                    if let index = podsViewModel.pods.firstIndex(where: { $0.id == currentPod.id }) {
                        podsViewModel.pods[index].items.append(newItem)
                    }
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
    
    private func refreshItem(with id: Int) {
        guard let currentPod = pod else { return }
        networkManager.fetchPodItem(podId: currentPod.id, itemId: id, userEmail: viewModel.email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedItem):
                    if let index = reorderedItems.firstIndex(where: { $0.id == id }) {
                        reorderedItems[index] = updatedItem
                    }
                    if let podIndex = podsViewModel.pods.firstIndex(where: { $0.id == currentPod.id }) {
                        podsViewModel.pods[podIndex].items = reorderedItems
                    }
                    needsRefresh = true
                case .failure(let error):
                    print("Failed to fetch updated item: \(error)")
                }
            }
        }
    }
}
