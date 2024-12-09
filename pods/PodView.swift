import SwiftUI
import AVFoundation
import Mixpanel

enum NavigationDestination: Hashable {
    case player(item: PodItem)
    case podInfo
    case podMembers
    case activityLog
    case trends(podId: Int)
    case fullAnalytics(column: PodColumn, logs: [PodItemActivityLog])
    case gracie(podId: Int)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .player(let item):
            hasher.combine("player")
            hasher.combine(item.id)
        case .podInfo:
            hasher.combine("podInfo")
        case .podMembers:
            hasher.combine("podMembers")
        case .activityLog:
            hasher.combine("activityLog")
        case .trends(let podId):
            hasher.combine("trends")
            hasher.combine(podId)
        case .fullAnalytics(let column, _):
                    hasher.combine("fullAnalytics")
                    hasher.combine(column.name)
        case .gracie(let podId):
            hasher.combine("gracie")
            hasher.combine(podId)
        }
    }

    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.player(let item1), .player(let item2)):
            return item1.id == item2.id
        case (.podInfo, .podInfo), (.podMembers, .podMembers), (.activityLog, .activityLog):
            return true
        case (.trends(let id1), .trends(let id2)):
            return id1 == id2
        case (.gracie(let id1), .gracie(let id2)):
            return id1 == id2
        case (.fullAnalytics(let column1, _), .fullAnalytics(let column2, _)):
                    return column1.name == column2.name
        default:
            return false
        }
    }
}



struct PodView: View {
    @Binding var pod: Pod
    @Binding var needsRefresh: Bool
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var isEditing = false
    @State private var reorderedItems: [PodItem] = []
    @State private var deletedItemIDs: [Int] = []
    @State private var showMenu = false
    @State private var isAnyItemEditing: Bool = false
    @State private var showDoneButton = false
    @State private var editingItemId: Int?
    @State private var selection: (podIndex: Int, itemIndex: Int)?
    var networkManager: NetworkManager = NetworkManager()
    @EnvironmentObject var uploadViewModel: UploadViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @EnvironmentObject var viewModel: OnboardingViewModel
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
    @State private var showLogActivitySheet = false
    @State private var selectedItemIndex: Int?
    
    @State private var podColumns: [PodColumn]
    @State private var showPodColumnsView = false
    
    @State private var visibleColumns: [String] = []
    
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
    
    @State private var activityLogs: [PodItemActivityLog] = []
    
    @State private var navigationPath = NavigationPath()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItemForMedia: PodItem?
    @State private var showCameraView = false

    @State private var isAddInputLoading = false
    @StateObject private var videoPreloader = VideoPreloader()
    
    @State private var pendingNavigation: NavigationDestination?
    @State private var isLoading = true
    
    
    init(pod: Binding<Pod>, needsRefresh: Binding<Bool>) {
        self._pod = pod
        self._needsRefresh = needsRefresh
        self._podColumns = State(initialValue: pod.wrappedValue.columns)
        self._visibleColumns = State(initialValue: pod.wrappedValue.visibleColumns)
        self._currentTitle = State(initialValue: pod.wrappedValue.title)
        self._currentDescription = State(initialValue: pod.wrappedValue.description ?? "")
        self._currentInstructions = State(initialValue: pod.wrappedValue.instructions ?? "")
        self._currentType = State(initialValue: pod.wrappedValue.type ?? "")
        
        
    }

    
    enum ViewType: String, CaseIterable {
        case list = "List"
        case table = "Table"
        case calendar = "Calendar"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
        ZStack {
//            (colorScheme == .dark ? Color(rgb: 14,14,14) : .white)
            (Color("iosbg"))
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {

                PodViewHeaderSection(
                                       selectedView: $selectedView,
                                       podTitle: currentTitle,
                                       showPodOptionsSheet: {
                                           showPodOptionsSheet = true
                                           Mixpanel.mainInstance().track(event: "Tapped Pod Options")
                                       },
                                       onDismiss: { dismiss() }  // Add this line
                                   )
                
                
                               if isLoading {
                                   VStack {
                                       Spacer()
                                       ProgressView()
                                           .scaleEffect(1.2)
                                           .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                       Spacer()
                                   }
                               } else {
                                   
//                                   ScrollView {
                                       VStack(spacing: 12) {
                                           switch selectedView {
                                           case .list:
                                               listView
                                           case .table:
                                               Text("Table View")
                                           case .calendar:
                                               Text("Calendar View")
                                           }
//                                           
//                                           if isCreatingNewItem {
//                                               newItemInputView
//                                               
//                                                   .padding(.bottom, 45)
//                                           }

                                       }
                                       

                         
                                       .safeAreaInset(edge: .bottom) {
                                         
                                           if !isCreatingNewItem{
                                               footerView
                                           } else {
                                               EmptyView()
                                           }
                                   }
                                 

                                   
                                   .padding(.bottom, keyboardOffset)
                               }
               
//                footerView
                
            }
        }
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .player(let item):
                    SingleVideoPlayerView(item: item)
            case .podInfo:
                PodInfoView(pod: $pod,
                            currentTitle: $currentTitle,
                            currentDescription: $currentDescription,
                            currentType: $currentType,
                            currentInstructions: $currentInstructions,
                        
                            onSave: { updatedTitle, updatedDescription, updatedInstructions, updatedType in
                    self.currentTitle = updatedTitle
                    self.currentDescription = updatedDescription
                    self.currentInstructions = updatedInstructions
                    self.currentType = updatedType
                    self.needsRefresh = true
                    fetchFullPodDetails()
                }
                )
            case .podMembers:
                PodMembersView(podId: pod.id, teamId: pod.teamId)
            case .activityLog:
                ActivityLogView(podId: pod.id)
            case .trends(let podId):

                ItemTrendsView(podId: podId, podItems: reorderedItems, podColumns: podColumns)
            case .fullAnalytics(let column, let logs):
                            FullAnalyticsView(column: column, activityLogs: logs)
            case .gracie(let podId):
                GracieView(podId: podId)
                        
                            
            }
        }

        .toolbar(.hidden, for: .navigationBar)
        
        
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
            
            self.activityLogs = pod.recentActivityLogs ?? []
            // Fetch details initially
             fetchFullPodDetails(showLoadingIndicator: true)
             
             // Listen for app becoming active
             NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                 fetchFullPodDetails(showLoadingIndicator: false)
             }
        }
        .onDisappear {

            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        .sheet(isPresented: $showPodOptionsSheet) {
            PodOptionsView(showPodOptionsSheet: $showPodOptionsSheet, showPodColumnsView: $showPodColumnsView, onDeletePod: deletePod, podName: pod.title, podId: pod.id,    navigationAction: { destination in
                showPodOptionsSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navigationPath.append(destination)
                }
            })
            
        }
        .sheet(isPresented: $showPodColumnsView) {
            PodColumnsView(
                podColumns: $podColumns,
                isPresented: $showPodColumnsView,
                podId: pod.id,
                networkManager: networkManager, visibleColumns: $visibleColumns
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
                    columnType: column.type, // Make sure this is correct
                    value: Binding(
                        get: { item.columnValues?[column.name] ?? .null },
                        set: { newValue in
                            updateColumnValue(itemIndex: itemIndex,
                                              columnName: column.name,
                                              newValue: newValue)
                        }
                    ),
                    onSave: { _ in },
                    networkManager: networkManager,
                    onViewTrendsTapped: {
                                                let relevantLogs = activityLogs.filter { $0.itemId == item.id && $0.columnValues[column.name] != nil }
                                                pendingNavigation = .fullAnalytics(column: column, logs: relevantLogs)
                                            }
                   
                )
                .presentationDetents([.height(UIScreen.main.bounds.height / 3)])
            }
        }
      
        .onChange(of: showColumnEditSheet) { newValue in
                     if !newValue, let pendingNav = pendingNavigation {
                         navigationPath.append(pendingNav)
                         pendingNavigation = nil
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
                    podColumns: $podColumns,
                    networkManager: networkManager,
                    allItems: Binding<[PodItem]>(
                        get: { self.reorderedItems },
                        set: { self.reorderedItems = $0 }
                    ),
                    visibleColumns: $visibleColumns
                )
                .id(reorderedItems[index].notes)  // Add this line to force view recreation
            }
        }
       

        
        .sheet(isPresented: $showLogActivitySheet) {
            if let index = selectedItemIndex {
                LogActivityView(
                    item: reorderedItems[index],
                    podColumns: podColumns,
                    podId: pod.id,

                    onActivityLogged: { newLog in
                                   self.onActivityLogged(newLog: newLog)
                               }
                )
                .presentationDetents([.height(UIScreen.main.bounds.height / 2)])
            }
        }
        
        
    }
        .navigationBarHidden(true)
    }
    
    private func fetchActivityLogs() {
        networkManager.fetchUserActivityLogs(podId: pod.id, userEmail: viewModel.email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let logs):
                    self.activityLogs = logs
                    
                case .failure(let error):
                    print("Failed to fetch activity logs: \(error)")
                }
            }
        }
     }
    
    private var footerView: some View {
        VStack {
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
//                        .lineLimit(1)
                }
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private func fetchFullPodDetails(showLoadingIndicator: Bool = true) {
        if showLoadingIndicator {
              isLoading = true
          }
        networkManager.fetchFullPodDetails(email: viewModel.email, podId: pod.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fullPod):
                    print("Fetched Pod Columns: \(fullPod.columns)")
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
                if showLoadingIndicator {
                              isLoading = false
                          }
            }
        }
    }
    
    
    private func waitForInitialPreload() {
        guard let firstItemId = reorderedItems.first?.id else {
            return
        }
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if self.videoPreloader.preloadProgress[firstItemId] ?? 0 >= 0.5 {
                timer.invalidate()
            }
        }
    }
    
    func onActivityLogged(newLog: PodItemActivityLog) {
        showTemporaryCheckmark(for: newLog.itemId)
        DispatchQueue.main.async {
            // Update activity logs
            let insertionIndex = self.activityLogs.firstIndex(where: { $0.loggedAt < newLog.loggedAt }) ?? self.activityLogs.endIndex
            self.activityLogs.insert(newLog, at: insertionIndex)
            self.activityLogs.sort()
            if self.activityLogs.count > 100 {
                self.activityLogs = Array(self.activityLogs.prefix(100))
            }
            
            // Update the pod's recentActivityLogs
            self.pod.recentActivityLogs = self.activityLogs
            
            // Update the item's column values
            if let itemIndex = self.reorderedItems.firstIndex(where: { $0.id == newLog.itemId }) {
                // Update the item's columnValues with the values from the activity log
                if self.reorderedItems[itemIndex].columnValues == nil {
                    self.reorderedItems[itemIndex].columnValues = [:]
                }
                
                // Update with new values from the activity log
                for (key, value) in newLog.columnValues {
                    self.reorderedItems[itemIndex].columnValues?[key] = value
                }
                
                // Also update in the pod.items
                if let podItemIndex = self.pod.items.firstIndex(where: { $0.id == newLog.itemId }) {
                    self.pod.items[podItemIndex].columnValues = self.reorderedItems[itemIndex].columnValues
                }
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
                       // You might want to show an error message to the user here
                   }
               }
           }
       }
    
    private func checkForRecentActivity(itemId: Int) {
        showTemporaryCheckmark(for: itemId)
    }
    
    private func showTemporaryCheckmark(for itemId: Int) {
        withAnimation {
            _ = itemsWithRecentActivity.insert(itemId)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                _ = self.itemsWithRecentActivity.remove(itemId)
            }
        }
    }
    
    func updatePod(title: String, description: String, type: String) {
        self.pod.title = title
        self.pod.description = description
        self.pod.type = type
        self.refreshID = UUID() // Force view update
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
        List {
            ForEach(reorderedItems.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reorderedItems[index].metadata)
                            .font(.system(size: 14))
                            .fontWeight(.regular)
                            .padding(.bottom, 4)
                        
                        HStack {
                            ForEach(podColumns.filter { visibleColumns.contains($0.name) }, id: \.name) { column in
                                columnView(name: column.name, item: reorderedItems[index])
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    VStack {
                        iconView(for: reorderedItems[index], index: index)
                        Spacer()
                        if itemsWithRecentActivity.contains(reorderedItems[index].id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                                .transition(.opacity)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                                .onTapGesture {
                                    selectedItemIndex = index
                                    showLogActivitySheet = true
                                    HapticFeedback.generate()
                                }
                        }
                    }
                    .padding(10)
                }
                .background(Color("iosnp"))
                .cornerRadius(10)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        let indexSet = IndexSet([index])
                        deleteItem(at: indexSet)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 15, bottom: 6, trailing: 15))
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedItemIndex = index
                    showCardSheet = true
                }
            }
            if isCreatingNewItem {
                newItemInputView
//                    .listRowInsets(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color("iosbg"))
            }
            
            // Insert the new item input row here
                  
        }
        .listStyle(PlainListStyle())
        .refreshable {
            fetchFullPodDetails(showLoadingIndicator: false)
        }
        .background(Color("iosbg"))
    }
    
    // Update the iconView function
    private func iconView(for item: PodItem, index: Int) -> some View {
        Group {
            if item.videoURL != nil || item.imageURL != nil {
                Image(systemName: "play")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? Color(rgb: 107,107,107) : Color(rgb:196, 198, 207))
                    .onTapGesture {
                        navigationPath.append(NavigationDestination.player(item: item))
                    }
            } else {
                Image(systemName: "camera")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? Color(rgb: 107,107,107) : Color(rgb:196, 198, 207))
                    .onTapGesture {
                        selectedItemForMedia = item
                        showCameraView = true
                    }
            }
        }
    }


//    private func columnView(name: String, item: PodItem) -> some View {
////        let value = item.userColumnValues?[name] ?? item.defaultColumnValues?[name] ?? .null
//        let value = item.columnValues?[name] ?? .null
//        let displayValue: ColumnValue = {
//            if case .array(let values) = value, !values.isEmpty {
//                return values[0]  // Take only the first value
//            }
//            return value
//        }()
//        return VStack {
//            Text("\(displayValue) \(name)")  // String interpolation will automatically use description
//                .font(.system(size: 13))
//        }
//        .padding(.horizontal,6)
//        .padding(.vertical,4)
//        .cornerRadius(4)
//        .background(Color("iosbtn"))
//        .cornerRadius(4)
//    }

    private func columnView(name: String, item: PodItem) -> some View {
        let column = podColumns.first { $0.name == name }
        let value = item.columnValues?[String(column?.id ?? 0)] ?? .null
        let displayValue: ColumnValue = {
            if case .array(let values) = value, !values.isEmpty {
                return values[0]
            }
            return value
        }()
        
        return VStack {
            Text("\(displayValue) \(column?.name ?? name)")
                .font(.system(size: 13))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .cornerRadius(4)
        .background(Color("iosbtn"))
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
                          ProgressView() // Display loader when loading
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
        
        // Initialize column values based on column type
        let newItemColumnValues: [String: ColumnValue] = pod.columns.reduce(into: [:]) { result, column in
            switch column.type {
            case "number":
                result[column.name] = .number(0) // Initialize number columns with 0
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
    var podTitle: String
        var showPodOptionsSheet: () -> Void
        var onDismiss: () -> Void
    
    var body: some View {
            VStack(spacing: 0) {
                // Navigation section
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(podTitle)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: showPodOptionsSheet) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                

            }
//            .background(colorScheme == .dark ? Color(rgb: 14,14,14) : .white)
            .background(Color("iosbg"))
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
    @EnvironmentObject var viewModel: OnboardingViewModel
    let networkManager: NetworkManager
    let onViewTrendsTapped: () -> Void
  

    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack {
                    if columnType == "text" {
                        CustomTextEditorWrapper(text: $textValue, isFocused: $isFocused, backgroundColor: backgroundColor)
                            .padding(.horizontal)
                            .focused($isFocused)
                    } else if columnType == "number" {
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

                    }else if columnType == "time" {
                        Text(textValue)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 40)
                            .padding(.horizontal)
                     
                        InlineTimePicker(timeValue: Binding(
                            get: {
                                TimeValue.fromString(textValue) ??
                                    TimeValue(hours: 0, minutes: 0, seconds: 0)
                            },
                            set: { newValue in
                                textValue = newValue.toString
                            }
                        ))
                        .frame(height: 150)
                    }
                        if columnType == "number" || columnType == "time" {
                                                viewTrendsButton
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
    
    private var viewTrendsButton: some View {
           Button(action: {
               presentationMode.wrappedValue.dismiss()
               onViewTrendsTapped()
           }) {
               HStack(spacing: 5) {
                   Image(systemName: "chart.line.uptrend.xyaxis")
                       .font(.system(size: 14, weight: .regular))
                   Text("View Trends")
                       .font(.system(size: 14, weight: .regular))
               }
               .padding(.vertical, 10)
               .padding(.horizontal, 15)
               .background(backgroundColor)
               .foregroundColor(.accentColor)
           }
           .buttonStyle(PlainButtonStyle())
           .padding(.top, 20)
       }


    private func saveValue() {

        let newValue: ColumnValue
           if columnType == "text" {
               newValue = .string(textValue)
           } else if columnType == "number", let numberValue = Double(textValue) {
               newValue = .number(numberValue)
           } else if columnType == "time", let timeValue = TimeValue.fromString(textValue) {
               newValue = .time(timeValue)  // Add this case
           } else {
               newValue = .null
           }

        
        networkManager.updatePodItemColumnValue(itemId: itemId, columnName: columnName, value: newValue, userEmail: viewModel.email) { result in
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
        return String(describing: columnValue)
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
    @Binding var item: PodItem
    @Binding var podColumns: [PodColumn]
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var itemName: String
    @State private var columnValues: [String: ColumnValue]
    let networkManager: NetworkManager
    @State private var showAddColumn = false
    @State private var showItemOptions = false
    @State private var addColumnOffset: CGFloat = UIScreen.main.bounds.height + 250
    @Binding var allItems: [PodItem]
    @State private var isAddingColumn = false
    @State private var newColumnName = ""
    @State private var newColumnType = ""
    let podId: Int
    @State private var itemOptionsOffset: CGFloat = UIScreen.main.bounds.height
    
    @FocusState private var isItemNameFocused: Bool
    
    @State private var showDeleteConfirmation = false
    @State private var expandedColumn: String?
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var itemNotes: String
    @FocusState private var focusedField: String?

    @Binding var visibleColumns: [String]
    @State private var hasUnsavedChanges = false




    @State private var groupedRowsCount: [String: Int] = [:]
    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
            let groupedColumns = columns.filter { $0.groupingType == "grouped" }
            let singularColumns = columns.filter { $0.groupingType == "singular" }
            return [groupedColumns, singularColumns].filter { !$0.isEmpty }
        }
    

    init(item: Binding<PodItem>, podId: Int, podColumns: Binding<[PodColumn]>, networkManager: NetworkManager, allItems: Binding<[PodItem]>, visibleColumns: Binding<[String]>) {
        self._item = item
        self._itemName = State(initialValue: item.wrappedValue.metadata)
        self._podColumns = podColumns
        self.networkManager = networkManager
        self._allItems = allItems
        self.podId = podId
        self._itemNotes = State(initialValue: item.wrappedValue.notes ?? "")
        self._visibleColumns = visibleColumns

        // Initialize columnValues based on item's columnValues or with empty values
        var initialColumnValues: [String: ColumnValue] = [:]
        var initialGroupedRowsCount: [String: Int] = [:]

        
        print("Raw item column values:", item.wrappedValue.columnValues)
        print("Raw columns:", podColumns.wrappedValue)
            
            for column in podColumns.wrappedValue {
                let columnId = String(column.id)
                print("Processing column:", column.name, "with ID:", columnId)
                
                if let value = item.wrappedValue.columnValues?[columnId] {
                    print("Found value for column", column.name, ":", value)
                    if column.groupingType == "grouped" {
                        if case .array(let columnValues) = value {
                            initialColumnValues[columnId] = .array(columnValues)
                            initialGroupedRowsCount[column.groupingType ?? ""] = columnValues.count
                        } else {
                            initialColumnValues[columnId] = .array([value])
                            initialGroupedRowsCount[column.groupingType ?? ""] = 1
                        }
                    } else {
                        initialColumnValues[columnId] = value
                    }
                } else {
                    print("No value found for column", column.name)
                    if column.groupingType == "grouped" {
                        initialColumnValues[columnId] = .array([])
                        initialGroupedRowsCount[column.groupingType ?? ""] = 0
                    } else {
                        initialColumnValues[columnId] = .null
                    }
                }
            }

            print("Final initialColumnValues:", initialColumnValues)


           self._columnValues = State(initialValue: initialColumnValues)
           self._groupedRowsCount = State(initialValue: initialGroupedRowsCount)
        
        print("Initializing columns:", podColumns)
        print("Initial column values:", columnValues)
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    (Color("iosbg"))
                        .edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        
                        VStack(alignment: .leading, spacing: 20) {
//                            TextField("Item Name", text: $itemName)
                            TextField("Item Name", text: Binding(
                                get: { itemName },
                                set: {
                                    itemName = $0
                                    checkForChanges()
                                }
                            ))
                                .font(.system(size: 18)).bold()
                                .background(Color.clear)
                                .focused($isItemNameFocused)
                            let columnGroups = groupColumns(podColumns)
                            ForEach(Array(columnGroups.indices), id: \.self) { groupIndex in
                                let columnGroup = columnGroups[groupIndex]
                                
                                if columnGroup.first?.groupingType == "singular" {
                                    ForEach(columnGroup, id: \.name) { column in
                                        SingularColumnView(
                                            column: column,
                                            columnValues: $columnValues,        // Pass the binding
                                            focusedField: _focusedField,        // Pass the FocusState
                                            expandedColumn: $expandedColumn,
                                            onValueChanged: checkForChanges
                                        )
                                    }
                                } else {
                                    GroupedColumnView(
                                        columnGroup: columnGroup,
                                        groupedRowsCount: groupedRowsCount[columnGroup.first?.groupingType ?? ""] ?? 1,
                                        onAddRow: {
                                            withAnimation {
                                                addRow(for: columnGroup)
                                            }
                                        },
                                        onDeleteRow: { rowIndex in
                                            withAnimation {
                                                deleteRow(at: rowIndex, in: columnGroup)
                                            }
                                        },
                                        columnValues: $columnValues,         // Add this
                                                   focusedField: _focusedField,         // Add this
                                                   expandedColumn: $expandedColumn,
                                        onValueChanged: checkForChanges
                                    )
                                }
                            }
                            VStack(alignment: .leading) {
                                Text("Notes")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 5)
                                    .kerning(0.2)
                                
//                                
//                                CustomTextEditor(text: $itemNotes, backgroundColor: UIColor(Color("iosnp")))
                                CustomTextEditor(text: Binding(
                                    get: { itemNotes },
                                    set: {
                                        itemNotes = $0
                                        checkForChanges()
                                    }
                                ), backgroundColor: UIColor(Color("iosnp")))
                                    .frame(height: 100)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .background(Color("iosnp"))
                                    .cornerRadius(12)
                            }
                            addColumnButton
                        }
                        
                        .padding()
                    }
                    
                    .sheet(isPresented: $showAddColumn) {
                        AddColumnView(isPresented: $showAddColumn, onAddColumn: addNewColumn)
                            .presentationDetents([.height(UIScreen.main.bounds.height / 3.5)])
                    }
                    
                    
                }

                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("Clear") {
                            if let focusedField = focusedField {
                                  let components = focusedField.split(separator: "_").map(String.init)
                                  if components.count == 2,
                                     let rowIndexInt = Int(components[1]) {
                                      // For grouped columns
                                      let columnName = components[0]
                                      if var columnValue = columnValues[columnName], case .array(var values) = columnValue {
                                          if rowIndexInt < values.count {
                                              values[rowIndexInt] = .null
                                              columnValues[columnName] = .array(values)
                                          }
                                      }
                                  } else {
                                      // For singular columns - just clear the value directly
                                      columnValues[focusedField] = .null
                                  }
                              }
                          }
                        .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Button("Done") {
                            focusedField = nil
                        }
                        .foregroundColor(.accentColor)
                        .fontWeight(.medium)
                    }
                }
                .navigationBarItems(
                            leading: Button(action: {
                                // Simply dismiss without saving
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.primary)
                            },
                            trailing: HStack(spacing: 12) {
                                Button(action: {
                                    showItemOptions = true
                                }) {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundColor(.primary)
                                }
                                
                                // Only show Done button if there are unsaved changes
                                if hasUnsavedChanges {
                                    Button(action: {
                                        saveChanges()
                                    }) {
                                        Text("Done")
                                            .fontWeight(.medium)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        )
                .navigationBarTitle("Edit Item", displayMode: .inline)
                .allowsHitTesting(!showItemOptions)
            }
            GeometryReader { geometry in
                
                ItemOptionsView(showItemOptionsSheet: $showItemOptions, onDeleteItem: deleteItem, onEditName: {
                    isItemNameFocused = true
                }, itemName: item.metadata,
                                onDuplicateItem: duplicateItem,  onMoveItem: moveItemToPod, currentPodId: podId,
                                dismissCardDetailView: { presentationMode.wrappedValue.dismiss()})
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(y: itemOptionsOffset)
                .onChange(of: showItemOptions) { oldValue, newValue in
                    withAnimation(.snappy()) {
                        itemOptionsOffset = newValue ? 0 : geometry.size.height
                    }
                }
                
                
            }
            .edgesIgnoringSafeArea(.all)
        }
 
        .onAppear {
            itemOptionsOffset = UIScreen.main.bounds.height
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Item"),
                message: Text("Delete \(item.metadata)?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteItem()
                },
                secondaryButton: .cancel())}
        
    }

    private func deleteRow(at index: Int, in columnGroup: [PodColumn]) {
        for column in columnGroup {
            if case .array(var values) = columnValues[String(column.id)] ?? .array([]) {
                if index < values.count {
                    values.remove(at: index)
                    columnValues[String(column.id)] = .array(values)
                }
            }
        }
        
        let groupType = columnGroup.first?.groupingType ?? ""
        if let currentCount = groupedRowsCount[groupType], currentCount > 0 {
            groupedRowsCount[groupType] = currentCount - 1
        }
        checkForChanges()
    }
  
    private func addRow(for columnGroup: [PodColumn]) {
        let groupType = columnGroup.first?.groupingType ?? ""
        let currentRowIndex = groupedRowsCount[groupType] ?? 1
        
        for column in columnGroup {
            let currentValue = columnValues[String(column.id)] ?? .array([])
            var values: [ColumnValue] = []
            
            if case .array(let existingValues) = currentValue {
                values = existingValues
            }
            
            if column.type == "number" {
                if case .number(1.0) = values.first {
                    values.append(.number(Double(values.count + 1)))
                } else {
                    values.append(values.last ?? .null)
                }
            } else {
                values.append(values.last ?? .null)
            }
            
            columnValues[String(column.id)] = .array(values)
        }
        
        groupedRowsCount[groupType] = currentRowIndex + 1
        checkForChanges()
    }


    
    
    private func checkForChanges() {
        hasUnsavedChanges = false
        
        // Check item name
        if itemName != item.metadata {
            hasUnsavedChanges = true
            return
        }
        
        // Check notes
        if itemNotes != (item.notes ?? "") {
            hasUnsavedChanges = true
            return
        }
        
        // Check column values including grouped columns
        for (key, value) in columnValues {
            let originalValue = item.columnValues?[key] ?? .null // Use .null as default for comparison
            
            let column = podColumns.first(where: { $0.name == key })
            let isGrouped = column?.groupingType == "grouped"
            
            if isGrouped {
                // For grouped columns, compare arrays
                if case .array(let newArray) = value,
                   case .array(let originalArray) = originalValue {
                    let newDescriptions = newArray.map { $0.description }
                    let originalDescriptions = originalArray.map { $0.description }
                    if newDescriptions != originalDescriptions {
                        hasUnsavedChanges = true
                        return
                    }
                } else if case .array(let newArray) = value, newArray.isEmpty, case .null = originalValue {
                    // Don't mark as changed if comparing empty array with null
                    continue
                } else {
                    hasUnsavedChanges = true
                    return
                }
            } else {
                // For singular columns, handle null values properly
                if case .null = value, case .null = originalValue {
                    continue
                }
                if value.description != originalValue.description {
                    hasUnsavedChanges = true
                    return
                }
            }
        }
    }

    private func moveItemToPod(_ toPodId: Int) {
        networkManager.moveItemToPod(itemId: item.id, fromPodId: podId, toPodId: toPodId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove the item from the current pod's items
                    if let index = allItems.firstIndex(where: { $0.id == item.id }) {
                        allItems.remove(at: index)
                    }
                    presentationMode.wrappedValue.dismiss()
                    // You might want to show a success message or update UI here
                case .failure(let error):
                    print("Failed to move item: \(error)")
                    // You might want to show an error message to the user here
                }
            }
        }
    }
    
    private func duplicateItem() {
        let newItem = PodItem(
            id: 0, // The server will assign the actual ID
            metadata: "\(itemName) (Copy)",
            itemType: item.itemType,
            notes: item.notes
        )
        
        networkManager.createPodItem(podId: podId, label: newItem.metadata, itemType: newItem.itemType, notes: newItem.notes, columnValues: newItem.columnValues ?? [:]) { result in
            switch result {
            case .success(let createdItem):
                DispatchQueue.main.async {
                    if let index = allItems.firstIndex(where: { $0.id == item.id }) {
                        allItems.insert(createdItem, at: index + 1)
                    } else {
                        allItems.append(createdItem)
                    }
                    print("Item duplicated successfully")
                }
            case .failure(let error):
                print("Failed to duplicate item: \(error)")
                // You might want to show an alert to the user here
            }
        }
    }
    
    
    private var addColumnButton: some View {
        HStack {
            Button(action: {
                print("add column tapped")
                showAddColumn = true
                addColumnOffset = UIScreen.main.bounds.height - 250
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .regular))
                    Text("Add column")
                        .font(.system(size: 16, weight: .regular))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 15)
                .background(Color("iosbg"))
                .foregroundColor(.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func deleteItem() {
        networkManager.deletePodItem(itemId: item.id) { success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    if let index = allItems.firstIndex(where: { $0.id == item.id }) {
                        allItems.remove(at: index)
                    }
                    presentationMode.wrappedValue.dismiss()
                    
                } else {
                    print("Failed to delete item: \(errorMessage ?? "Unknown error")")
                    // You might want to show an error alert to the user here
                }
            }
        }
    }
    

    private func addNewColumn(title: String, type: String) {

        isAddingColumn = true
        showAddColumn = false
        networkManager.addColumnToPod(podId: podId, columnName: title, columnType: type) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let column):
                    let newColumn = PodColumn(
                        id: column.id,
                        name: title,
                        type: type
                    )
                    podColumns.append(newColumn)
                    
                    // Use column ID as key instead of name
                    columnValues[String(column.id)] = .null
                    
                    if item.columnValues == nil {
                        item.columnValues = [:]
                    }
                    item.columnValues?[String(column.id)] = .null
                    
                    
                    checkForChanges()
                    showAddColumn = false
                case .failure(let error):
                    print("Failed to add new column: \(error)")
                }
            }
        }
    }
    
    private func updateVisibleColumnsOnServer() {
        networkManager.updateVisibleColumns(podId: podId, columns: visibleColumns) { result in
            switch result {
            case .success:
                print("Visible columns updated successfully")
            case .failure(let error):
                print("Failed to update visible columns: \(error)")
                // You might want to show an alert to the user here
            }
        }
    }
 
    private func saveChanges() {
        var hasChanges = false
        var updatedColumnValues: [String: ColumnValue] = [:]

        print("Starting save changes for PodItemUserValue")

        for (key, newValue) in columnValues {
//            guard let column = podColumns.first(where: { $0.name == key }) else {
//                continue
//            }
            guard let column = podColumns.first(where: { String($0.id) == key }) else {
                     continue
                 }
            let isGrouped: Bool = (column.groupingType == "grouped")

            let originalValue: ColumnValue = item.columnValues?[key] ?? .null

            var updatedValue: ColumnValue = originalValue

            if isGrouped {
                // Handle grouped columns (arrays)
                let newValuesArray: [ColumnValue]
                if case .array(let array) = newValue {
                    newValuesArray = array
                } else {
                    newValuesArray = [newValue]
                }

                let originalValuesArray: [ColumnValue]
                if case .array(let array) = originalValue {
                    originalValuesArray = array
                } else {
                    originalValuesArray = [originalValue]
                }

                let newDescriptions: [String] = newValuesArray.map { $0.description }
                let originalDescriptions: [String] = originalValuesArray.map { $0.description }

                if newDescriptions != originalDescriptions {
                    updatedValue = .array(newValuesArray)
                    hasChanges = true
                }
            } else {
                // Handle singular columns
                let newDescription: String = newValue.description
                let originalDescription: String = originalValue.description

                if newDescription != originalDescription {
                    updatedValue = newValue
                    hasChanges = true
                }
            }

            updatedColumnValues[key] = updatedValue
        }

        // Check if item name or notes have changed
        if itemName != item.metadata || itemNotes != (item.notes ?? "") {
            hasChanges = true
        }

        if hasChanges {
            print("Updating PodItemUserValue with values:", updatedColumnValues)
            networkManager.updatePodItem(
                itemId: item.id,
                newLabel: itemName,
                newNotes: itemNotes,
                newColumnValues: updatedColumnValues,
                userEmail: viewModel.email
            ) { (result: Result<Void, Error>) in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("Column values before update:", columnValues)
                        
                        // Create a new copy of the values
                           var newColumnValues: [String: ColumnValue] = [:]
                           for (key, value) in updatedColumnValues {
                               newColumnValues[key] = value
                           }
//                           
//                   
//                        self.item.metadata = self.itemName
//                        self.item.notes = self.itemNotes
//                        self.item.columnValues = updatedColumnValues
                        // Update everything at once
                           self.item.metadata = self.itemName
                           self.item.notes = self.itemNotes
                           self.item.columnValues = newColumnValues  // Use the copy
                        self.presentationMode.wrappedValue.dismiss()
                    case .failure(let error):
                        print("Failed to update pod item: \(error)")
                        // Handle the error as needed
                    }
                }
            }
        } else {
            print("No changes detected")
            self.presentationMode.wrappedValue.dismiss()
        }
    }

    

}

struct SingularColumnView: View {
    let column: PodColumn
    @Binding var columnValues: [String: ColumnValue]
    @FocusState var focusedField: String?
    @Binding var expandedColumn: String?
    let onValueChanged: () -> Void
    
    
    var body: some View {
     
        
        VStack(alignment: .leading, spacing: 5) {
            Text(column.name)
                .font(.system(size: 16))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundColor(.primary)
                .kerning(0.2)
            
            ColumnValueInputView(
                column: column,
                columnValues: $columnValues,
                focusedField: _focusedField,
                expandedColumn: $expandedColumn,
                onValueChanged: onValueChanged
            )
            .padding(.vertical, 8)
            .background(Color("iosnp"))
            .cornerRadius(8)
        }
    }
}

struct GroupedColumnHeaderView: View {
    let columnGroup: [PodColumn]
    
    var body: some View {
        HStack(spacing: 15) {
            ForEach(columnGroup, id: \.id) { column in
                Text(column.name)
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundColor(.primary)
                    .kerning(0.2)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// 3. Create a view for grouped column rows
struct GroupedColumnRowView: View {
    let columnGroup: [PodColumn]
    let rowIndex: Int
    @Binding var columnValues: [String: ColumnValue]
    @FocusState var focusedField: String?
    @Binding var expandedColumn: String?
    let onDelete: () -> Void
    let onValueChanged: () -> Void
    
    
    var body: some View {
        List {
            HStack(spacing: 15) {
                ForEach(columnGroup, id: \.id) { column in
                    GroupedColumnInputView(
                                           column: column,
                                           rowIndex: rowIndex,
                                           columnValues: $columnValues,
                                           focusedField: _focusedField,
                                           expandedColumn: $expandedColumn,
                                           onValueChanged: onValueChanged
                                       )
                                       .frame(maxWidth: .infinity)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .listStyle(PlainListStyle())
        .frame(height: 44)
    }
}

// 4. Create a view for the grouped columns section
struct GroupedColumnView: View {
    let columnGroup: [PodColumn]
    let groupedRowsCount: Int
    let onAddRow: () -> Void
    let onDeleteRow: (Int) -> Void
    @Binding var columnValues: [String: ColumnValue]    // Add this
    @FocusState var focusedField: String?              // Add this
    @Binding var expandedColumn: String?               // Add this
    let onValueChanged: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupedColumnHeaderView(columnGroup: columnGroup)
            
            ForEach(0..<groupedRowsCount, id: \.self) { rowIndex in
                GroupedColumnRowView(
                    columnGroup: columnGroup,
                    rowIndex: rowIndex,
                    columnValues: $columnValues,        // Pass binding
                    focusedField: _focusedField,        // Pass FocusState
                    expandedColumn: $expandedColumn,    // Pass binding
                    onDelete: { onDeleteRow(rowIndex) },
                    onValueChanged: onValueChanged
                )
            }
            
            Button(action: onAddRow) {
                Text("Add Entry")
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(.top, 5)
    }
}

struct ColumnValueInputView: View {
    let column: PodColumn
    @Binding var columnValues: [String: ColumnValue]
    @FocusState var focusedField: String?
    @Binding var expandedColumn: String?
    let onValueChanged: () -> Void
    
    var body: some View {
        let columnId = String(column.id)
        Group {
            if column.type == "text" {
                let textBinding = Binding<String>(
                    get: { columnValues[columnId]?.description ?? "" },
                    set: {
                        columnValues[columnId] = .string($0)
                        onValueChanged()
                    }
                )
                
                TextField("", text: textBinding)
                    .focused($focusedField, equals: columnId)
                    .foregroundColor(.primary)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .cornerRadius(12)
                    .background(Color("iosnp"))
            }
            else if column.type == "number" {
                let numberBinding = Binding<String>(
                    get: { columnValues[columnId]?.description ?? "" },
                    set: { newValue in
                        if let num = Double(newValue) {
                            columnValues[columnId] = .number(num)
                        } else {
                            columnValues[columnId] = .null
                        }
                        onValueChanged()
                    }
                )
                
                TextField("", text: numberBinding)
                    .focused($focusedField, equals: columnId)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .cornerRadius(12)
                    .background(Color("iosnp"))
            }
            else if column.type == "time" {
                Button(action: {
                    withAnimation {
                        expandedColumn = (expandedColumn == columnId) ? nil : columnId
                    }
                }) {
                    Text(columnValues[columnId]?.description ?? "")
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                }
                
                if expandedColumn == columnId {
                    InlineTimePicker(timeValue: Binding(
                        get: {
                            if case .time(let timeValue) = columnValues[columnId] {
                                return timeValue
                            }
                            return TimeValue(hours: 0, minutes: 0, seconds: 0)
                        },
                        set: {
                            columnValues[columnId] = .time($0)
                            onValueChanged()
                        }
                    ))
                    .frame(height: 150)
                    .transition(.opacity)
                }
            }
        }
    }
}

struct GroupedColumnInputView: View {
    let column: PodColumn
    let rowIndex: Int
    @Binding var columnValues: [String: ColumnValue]
    @FocusState var focusedField: String?
    @Binding var expandedColumn: String?
    let onValueChanged: () -> Void
    
    var body: some View {
        let columnId = String(column.id)
        
        let currentValue = columnValues[columnId] ?? .array([])
        let values: [ColumnValue] = {
            if case .array(let arr) = currentValue {
                return arr
            }
            return [currentValue]
        }()
        
        let value = rowIndex < values.count ? values[rowIndex] : .null
        
        Group {
            if column.type == "text" {
                let textBinding = Binding<String>(
                    get: { value.description },
                    set: { newValue in
                        var updatedValues = values
                        while updatedValues.count <= rowIndex {
                            updatedValues.append(.null)
                        }
                        updatedValues[rowIndex] = .string(newValue)
                        columnValues[columnId] = .array(updatedValues)
                        onValueChanged()
                    }
                )
                
                TextField("", text: textBinding)
                    .focused($focusedField, equals: "\(columnId)_\(rowIndex)")
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(Color("iosnp"))
                    .cornerRadius(12)
            }
            else if column.type == "number" {
                let numberBinding = Binding<String>(
                    get: { value.description },
                    set: { newValue in
                        var updatedValues = values
                        while updatedValues.count <= rowIndex {
                            updatedValues.append(.null)
                        }
                        if let num = Double(newValue) {
                            updatedValues[rowIndex] = .number(num)
                        } else {
                            updatedValues[rowIndex] = .null
                        }
                        columnValues[columnId] = .array(updatedValues)
                        onValueChanged()
                    }
                )
                
                TextField("", text: numberBinding)
                    .focused($focusedField, equals: "\(columnId)_\(rowIndex)")
                    .keyboardType(.decimalPad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(Color("iosnp"))
                    .cornerRadius(12)
            }
            else if column.type == "time" {
                Button(action: {
                    withAnimation {
                        expandedColumn = (expandedColumn == "\(columnId)_\(rowIndex)") ? nil : "\(columnId)_\(rowIndex)"
                    }
                }) {
                    Text(value.description)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                }
                
                if expandedColumn == "\(columnId)_\(rowIndex)" {
                    InlineTimePicker(timeValue: Binding(
                        get: {
                            if case .time(let timeValue) = value {
                                return timeValue
                            }
                            return TimeValue(hours: 0, minutes: 0, seconds: 0)
                        },
                        set: { newValue in
                            var updatedValues = values
                            while updatedValues.count <= rowIndex {
                                updatedValues.append(.null)
                            }
                            updatedValues[rowIndex] = .time(newValue)
                            columnValues[columnId] = .array(updatedValues)
                            onValueChanged()
                        }
                    ))
                    .frame(height: 150)
                    .transition(.opacity)
                }
            }
        }
    }
}


struct AddColumnView: View {
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    var onAddColumn: (String, String) -> Void
    @State private var columnType: ColumnType = .number
    @State private var columnName: String = ""
    @Environment(\.presentationMode) var presentationMode
    
    
    // Add the computed property here, right after your properties
      private var columnTypeIcon: String {
          switch columnType {
          case .number:
              return "number"
          case .text:
              return "textformat"
          case .time:
              return "timer"
          }
      }
    
    
    enum ColumnType: String, CaseIterable {
        case number = "number"
        case text = "text"
        case time = "time"
        
        var displayText: String {
            switch self {
            case .number:
                return "Number"
            case .text:
                return "Text"
            case .time:
                return "Time"
            }
        }
    }
    
    var body: some View {
        NavigationView{
            ZStack {
                Color("mxdBg")
                    .ignoresSafeArea(.all)
                VStack(spacing: 0) {
                    
                    VStack(spacing: 20) {
                        // Pod Name Input
                        HStack {
                            TextField("Column Name", text: $columnName)
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                        )
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Pod Mode Selection
                        HStack {
                            Image(systemName: (columnTypeIcon))
                                .foregroundColor(.accentColor)
                            Text("Column Type")
                            Spacer()
                            Picker("Column Type", selection: $columnType) {
                                ForEach(ColumnType.allCases, id: \.self) { type in
                                    Text(type.displayText)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:244, 246, 247))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(borderColor, lineWidth: colorScheme == .dark ? 1 : 0)
                        )
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
            .background(Color("mxdBg").edgesIgnoringSafeArea(.all))
            .navigationTitle("Create a new column")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                },
                trailing: Button("Done") {
                    onAddColumn(columnName, columnType.rawValue)
                    isPresented = false
                }
                .foregroundColor(Color.accentColor)
            )
        }
    }
    

    
    private var borderColor: Color {
        colorScheme == .dark ? Color(rgb: 86, 86, 86) : Color(rgb: 230, 230, 230)
    }
    
    private func columnTypeButton(title: String, icon: String, type: String) -> some View {
        Button(action: {
            onAddColumn(title, type)
            isPresented = false
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 16))
            }
            .padding(10)

            .background(Color("ltBg"))
            .cornerRadius(10)
        }
        .foregroundColor(.primary)
    }
}

struct LogActivityView: View {
    let item: PodItem
    let podColumns: [PodColumn]
    let podId: Int
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var columnValues: [String: ColumnValue]
    @State private var activityNote: String = ""
    @State private var expandedColumn: String?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showNotesInput = false
    var onActivityLogged: (PodItemActivityLog) -> Void
    @State private var skippedColumns: Set<String> = []
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false
    @FocusState private var focusedField: String?
    @State private var groupedRowsCount: [String: Int] = [:]

    init(item: PodItem, podColumns: [PodColumn], podId: Int, onActivityLogged: @escaping (PodItemActivityLog) -> Void) {
            self.item = item
            self.podColumns = podColumns
            self.podId = podId
            self.onActivityLogged = onActivityLogged
            
            // Initialize column values with proper structure
            var initialColumnValues: [String: ColumnValue] = [:]
            var initialGroupedRowsCount: [String: Int] = [:]
            
            for column in podColumns {
                if let value = item.columnValues?[String(column.id)] {
                    if column.groupingType == "grouped" {
                        if case .array(let columnValues) = value {
                            initialColumnValues[String(column.id)] = .array(columnValues)
                            initialGroupedRowsCount[column.groupingType ?? ""] = columnValues.count
                        } else {
                            initialColumnValues[String(column.id)] = .array([value])
                            initialGroupedRowsCount[column.groupingType ?? ""] = 1
                        }
                    } else {
                        initialColumnValues[String(column.id)] = value
                    }
                } else {
                    initialColumnValues[String(column.id)] = .null
                    if column.groupingType == "grouped" {
                        initialGroupedRowsCount[column.groupingType ?? ""] = 0
                    }
                }
            }
            
            _columnValues = State(initialValue: initialColumnValues)
            _groupedRowsCount = State(initialValue: initialGroupedRowsCount)
        }
    
    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singularColumns = columns.filter { $0.groupingType == "singular" }
        
        // Return grouped first, then singular
        return [groupedColumns, singularColumns].filter { !$0.isEmpty }
    }


    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Handle case when there are no columns
                    if podColumns.isEmpty {
                        Text("No columns available to log.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        
                        let columnGroups = groupColumns(podColumns)
                                   ForEach(Array(columnGroups.indices), id: \.self) { groupIndex in
                                       let columnGroup = columnGroups[groupIndex]
                                       
                                       if columnGroup.first?.groupingType == "singular" {
                                           ForEach(columnGroup, id: \.id) { column in
                                      
                                                   SingularColumnView(
                                                       column: column,
                                                       columnValues: $columnValues,
                                                       focusedField: _focusedField,
                                                       expandedColumn: $expandedColumn,
                                                       onValueChanged: {
                                                           // Optional: Add any value change handling here
                                                       }
                                                   )
                                             
                                           }
                                       } else {
                                           GroupedColumnView(
                                               columnGroup: columnGroup,
                                               groupedRowsCount: groupedRowsCount[columnGroup.first?.groupingType ?? ""] ?? 1,
                                               onAddRow: {
                                                   withAnimation {
                                                       addRow(for: columnGroup)
                                                   }
                                               },
                                               onDeleteRow: { rowIndex in
                                                   withAnimation {
                                                       deleteRow(at: rowIndex, in: columnGroup)
                                                   }
                                               },
                                               columnValues: $columnValues,
                                               focusedField: _focusedField,
                                               expandedColumn: $expandedColumn,
                                               onValueChanged: {
                                                   // Optional: Add any value change handling here
                                               }
                                           )
                                       }
                                   }

                        
                        VStack(alignment: .leading, spacing: 5) {
                            Button(action: {
                                withAnimation {
                                    showDatePicker.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.gray)
                                    Text("Date")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(formatDate(selectedDate))
                                        .foregroundColor(.accentColor)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal)
                                .background(Color("iosnp"))
                                .cornerRadius(8)
                            }
                            
                            if showDatePicker {
                                DatePickerWheel(selectedDate: $selectedDate)
                                    .frame(height: 150)
                                    .transition(.opacity)
                            }
                        }
                    }

                    // Notes section
                    if showNotesInput {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Notes")
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 5)
                                .kerning(0.2)
                            
                            CustomTextEditor(text: $activityNote, backgroundColor: UIColor(Color("iosnp")))
                                .frame(height: 100)
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(Color("iosnp"))
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                showNotesInput = true
                            }
                        }) {
                            Text("Add Notes")
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Error message if any
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }

            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Clear") {
                        if let focusedField = focusedField {
                            let components = focusedField.split(separator: "_").map(String.init)
                            if components.count == 2,
                               let rowIndexInt = Int(components[1]) {
                                // Handle grouped columns
                                let columnName = String(components[0])
                                if let currentValue = columnValues[columnName],
                                   case .array(var values) = currentValue {
                                    if rowIndexInt < values.count {
                                        values[rowIndexInt] = .null
                                        columnValues[columnName] = .array(values)
                                    }
                                }
                            } else {
                                // Handle singular columns
                                columnValues[focusedField] = .null
                            }
                        }
                    }
                    .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Button("Done") {
                        focusedField = nil
                    }
                    .foregroundColor(.accentColor)
                    .fontWeight(.medium)
                }
            }
  
            .background(Color("iosbg").edgesIgnoringSafeArea(.all)) // Apply background color
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                },
                trailing: Button("Done") {
                    submitActivity()
                    HapticFeedback.generateLigth()
                }
                .foregroundColor(Color.accentColor)
            )
  
        }
    }
    
    
    private func addRow(for columnGroup: [PodColumn]) {
        let groupType = columnGroup.first?.groupingType ?? ""
        let currentRowIndex = groupedRowsCount[groupType] ?? 1
        
        for column in columnGroup {
//            guard !skippedColumns.contains(column.id) else { continue }
            
            if case .array(let existingValues) = columnValues[String(column.id)] {
                var values = existingValues
                
                // Determine the new value based on column type
                let newValue: ColumnValue
                if column.type == "number" {
                    if case .number(1.0) = values.first {
                        newValue = .number(Double(values.count + 1))
                    } else {
                        newValue = values.last ?? .null
                    }
                } else {
                    newValue = values.last ?? .null
                }
                
                values.append(newValue)
                columnValues[String(column.id)] = .array(values)
            } else {
                columnValues[String(column.id)] = .array([.null])
            }
        }
        
        groupedRowsCount[groupType] = currentRowIndex + 1
    }
    
    private func deleteRow(at index: Int, in columnGroup: [PodColumn]) {
           for column in columnGroup {
               if case .array(var values) = columnValues[String(column.id)] {
                   if index < values.count {
                       values.remove(at: index)
                       columnValues[String(column.id)] = .array(values)
                   }
               }
           }
           
           let groupType = columnGroup.first?.groupingType ?? ""
           if let currentCount = groupedRowsCount[groupType], currentCount > 0 {
               groupedRowsCount[groupType] = currentCount - 1
           }
       }

//       private func submitActivity() {
//           isSubmitting = true
//           
//           // Prepare the column values for submission
//           var submissionValues: [String: ColumnValue] = [:]
//           
//           for (columnName, value) in columnValues {
//               guard !skippedColumns.contains(columnName),
//                     let column = podColumns.first(where: { $0.name == columnName }) else { continue }
//               
//               if column.groupingType == "grouped" {
//                   if case .array(let values) = value {
//                       submissionValues[columnName] = .array(values)
//                   }
//               } else {
//                   submissionValues[columnName] = value
//               }
//           }
//           
//           NetworkManager().createActivityLog(
//               itemId: item.id,
//               podId: podId,
//               userEmail: viewModel.email,
//               columnValues: submissionValues,
//               podColumns: podColumns,
//               notes: activityNote,
//               loggedAt: selectedDate
//           ) { result in
//               DispatchQueue.main.async {
//                   isSubmitting = false
//                   switch result {
//                   case .success(let newLog):
//                       onActivityLogged(newLog)
//                       presentationMode.wrappedValue.dismiss()
//                   case .failure(let error):
//                       errorMessage = error.localizedDescription
//                   }
//               }
//           }
//       }
    private func submitActivity() {
        isSubmitting = true
        
        var submissionValues: [String: ColumnValue] = [:]
        
        // Prepare values for submission
        for (columnId, value) in columnValues {
            guard !skippedColumns.contains(columnId) else { continue }
            submissionValues[columnId] = value
        }
        
        NetworkManager().createActivityLog(
            itemId: item.id,
            podId: podId,
            userEmail: viewModel.email,
            columnValues: submissionValues,
            podColumns: podColumns,
            notes: activityNote,
            loggedAt: selectedDate
        ) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success(let newLog):
                    // This will update both the activity log and the item's column values
                    // since they're one and the same
                    var updatedItem = self.item
                    updatedItem.columnValues = submissionValues
                    
                    // Pass both the log and the updated item values up to parent
                    self.onActivityLogged(newLog)
                    
                    self.presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today, \(date.formatted(date: .omitted, time: .shortened))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(date.formatted(date: .omitted, time: .shortened))"
        } else {
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
        }
    }

    
    private func timeValue(for columnName: String) -> TimeValue {
        guard let value = columnValues[columnName] else {
            return TimeValue(hours: 0, minutes: 0, seconds: 0)
        }
        
        switch value {
        case .time(let timeValue):
            return timeValue
        case .number(let seconds):
            return TimeValue.fromSeconds(Int(seconds))
        case .string(let strValue):
            return TimeValue.fromString(strValue) ?? TimeValue(hours: 0, minutes: 0, seconds: 0)
        case .array(let values):
            // If it's an array, try to get time value from the first element
            if let firstValue = values.first {
                switch firstValue {
                case .time(let timeValue):
                    return timeValue
                case .string(let strValue):
                    return TimeValue.fromString(strValue) ?? TimeValue(hours: 0, minutes: 0, seconds: 0)
                case .number(let seconds):
                    return TimeValue.fromSeconds(Int(seconds))
                default:
                    return TimeValue(hours: 0, minutes: 0, seconds: 0)
                }
            }
            return TimeValue(hours: 0, minutes: 0, seconds: 0)
        case .null:
            return TimeValue(hours: 0, minutes: 0, seconds: 0)
        }
    }

    private func stringValue(for columnName: String) -> String {
        guard let value = columnValues[columnName] else {
            return ""
        }
        return value.description
    }

    private func numberValue(for columnName: String) -> Double {
        guard let value = columnValues[columnName] else {
            return 0
        }
        
        switch value {
        case .number(let num):
            return num
        case .array(let values):
            // If it's an array, try to get number from the first element
            if let firstValue = values.first, case .number(let num) = firstValue {
                return num
            }
            return 0
        default:
            return 0
        }
    }


}

struct ColumnInputView: View {
    let column: PodColumn
    @Binding var columnValues: [String: [ColumnValue]]
    @Binding var expandedColumn: String?
    let focusedField: FocusState<String?>.Binding
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(column.name)
                .font(.system(size: 16))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundColor(.primary)
                .padding(.horizontal, 5)
                .kerning(0.2)
            
            ColumnInputField(
                column: column,
                rowIndex: 0,
                columnGroup: [column], // Single column group for non-grouped columns
                columnIndex: 0,
                totalRows: 1,
                columnValues: $columnValues,
                expandedColumn: $expandedColumn,
                focusedField: focusedField
            )
        }
    }
}

struct ColumnInputField: View {
    let column: PodColumn
    let rowIndex: Int
    let columnGroup: [PodColumn] // Add this to know about all columns in the row
      let columnIndex: Int // Add this to know current column position
      let totalRows: Int
    @Binding var columnValues: [String: [ColumnValue]]
    @Binding var expandedColumn: String?
    let focusedField: FocusState<String?>.Binding
    

    
    var body: some View {
        Group {
            if column.type == "text" {
                TextField("", text: Binding(
                    get: { stringValue(for: column.name, rowIndex: rowIndex) },
                    set: { updateValue(.string($0), for: column.name, rowIndex: rowIndex) }
                ))
                .multilineTextAlignment(.center)
                .textFieldStyle(PlainTextFieldStyle())
            } // In ColumnInputField's body view, replace the number TextField section:
            else if column.type == "number" {
                TextField("", text: Binding(
                    get: { stringValue(for: column.name, rowIndex: rowIndex) },
                    set: { newValue in
                        if let number = Double(newValue) {
                            updateValue(.number(number), for: column.name, rowIndex: rowIndex)
                        }
                    }
                ))
                .focused(focusedField, equals: "\(column.name)_\(rowIndex)")
                .keyboardType(.decimalPad)
                .multilineTextAlignment(columnGroup.count > 1 ? .center : .leading)
                .textFieldStyle(PlainTextFieldStyle())

            } else if column.type == "time" {
                Button(action: {
                    withAnimation {
                        expandedColumn = (expandedColumn == column.name) ? nil : column.name
                    }
                }) {
                    Text(stringValue(for: column.name, rowIndex: rowIndex))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                if expandedColumn == column.name {
                    InlineTimePicker(timeValue: Binding(
                        get: { timeValue(for: column.name, rowIndex: rowIndex) },
                        set: { updateValue(.time($0), for: column.name, rowIndex: rowIndex) }
                    ))
                    .frame(height: 150)
                    .transition(.opacity)
                }
            }
        }
        .padding(.vertical, columnGroup.count > 1 ? 10 : 12)
        .padding(.horizontal)
        .background(Color("iosnp"))
        .cornerRadius(8)
    }
    
    private func stringValue(for columnName: String, rowIndex: Int) -> String {
        let values = columnValues[columnName] ?? []
        return rowIndex < values.count ? String(describing: values[rowIndex]) : ""
    }

    
    private func timeValue(for columnName: String, rowIndex: Int) -> TimeValue {
        let values = columnValues[columnName] ?? []
        guard rowIndex < values.count else { return TimeValue(hours: 0, minutes: 0, seconds: 0) }

        switch values[rowIndex] {
        case .time(let value):
            return value
        case .number(let seconds):
            return TimeValue.fromSeconds(Int(seconds))
        case .string(let value):
            return TimeValue.fromString(value) ?? TimeValue(hours: 0, minutes: 0, seconds: 0)
        case .array(let array):
            // Handle the case where a row index corresponds to an array of values
            if let firstValue = array.first, case .time(let timeValue) = firstValue {
                return timeValue
            }
            return TimeValue(hours: 0, minutes: 0, seconds: 0)
        case .null:
            return TimeValue(hours: 0, minutes: 0, seconds: 0)
        }
    }

    
    private func updateValue(_ value: ColumnValue, for columnName: String, rowIndex: Int) {
        var values = columnValues[columnName] ?? []
        while values.count <= rowIndex {
            values.append(.null)
        }
        values[rowIndex] = value
        columnValues[columnName] = values
    }
}

struct InlineNumberPicker: View {
    @Binding var value: Int
    
    var body: some View {
        Picker("", selection: $value) {
            ForEach(0...1000, id: \.self) { number in
                Text("\(number)").tag(number)
            }
        }
        .pickerStyle(WheelPickerStyle())
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    let backgroundColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = backgroundColor
        textView.textColor = UIColor.label  // This adapts to light/dark mode automatically
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
        uiView.backgroundColor = backgroundColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor

        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

struct InlineTimePicker: View {
    @Binding var timeValue: TimeValue
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Hours Picker
                Picker("Hours", selection: $timeValue.hours) {
                    ForEach(0...23, id: \.self) { hour in
                        Text("\(hour)h")
                            .tag(hour)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: geometry.size.width / 3)
                .clipped()
                
                // Minutes Picker
                Picker("Minutes", selection: $timeValue.minutes) {
                    ForEach(0...59, id: \.self) { minute in
                        Text("\(minute)m")
                            .tag(minute)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: geometry.size.width / 3)
                .clipped()
                
                // Seconds Picker
                Picker("Seconds", selection: $timeValue.seconds) {
                    ForEach(0...59, id: \.self) { second in
                        Text("\(second)s")
                            .tag(second)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: geometry.size.width / 3)
                .clipped()
            }
        }
    }
}
