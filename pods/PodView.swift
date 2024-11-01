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
    case sydney(podId: Int)

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
        case .sydney(let podId):
            hasher.combine("sydney")
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
        case (.sydney(let id1), .sydney(let id2)):
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
    
    
    init(pod: Binding<Pod>, needsRefresh: Binding<Bool>) {
        self._pod = pod
        self._needsRefresh = needsRefresh
        self._podColumns = State(initialValue: pod.wrappedValue.columns)
        self._visibleColumns = State(initialValue: pod.wrappedValue.visibleColumns)
        self._currentTitle = State(initialValue: pod.wrappedValue.title)
        self._currentDescription = State(initialValue: pod.wrappedValue.description ?? "")
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
            (colorScheme == .dark ? Color(rgb: 14,14,14) : .white)
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
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .player(let item):
                    SingleVideoPlayerView(item: item)
            case .podInfo:
                PodInfoView(pod: $pod,
                            currentTitle: $currentTitle,
                            currentDescription: $currentDescription,
                            currentType: $currentType,
                            onSave: { updatedTitle, updatedDescription, updatedType in
                    self.currentTitle = updatedTitle
                    self.currentDescription = updatedDescription
                    self.currentType = updatedType
                    self.needsRefresh = true
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
            case .sydney(let podId):
                SydneyView(podId: podId)
                        
                            
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
            print(activityLogs, "logs")
            fetchFullPodDetails()
        }
        .onDisappear {
            //            isTabBarVisible.wrappedValue = true
            
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
        .onAppear {
                   fetchActivityLogs()
               }
        .onChange(of: showColumnEditSheet) { newValue in
                     if !newValue, let pendingNav = pendingNavigation {
                         navigationPath.append(pendingNav)
                         pendingNavigation = nil
                     }
                 }
      
        
        .sheet(isPresented: $showCardSheet) {
            if let index = selectedItemIndex {
                CardDetailView(item: Binding<PodItem>(
                    get: { self.reorderedItems[index] },
                    set: { self.reorderedItems[index] = $0 }
                ), podId: pod.id, podColumns: $podColumns, networkManager: networkManager,
                               allItems: Binding<[PodItem]>(
                                get: { self.reorderedItems },
                                set: { self.reorderedItems = $0 }
                               ), visibleColumns: $visibleColumns)
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
       
         networkManager.fetchPodActivityLogs(podId: pod.id) { result in
             DispatchQueue.main.async {
                 
                 switch result {
                 case .success(let logs):
                     self.activityLogs = logs
                 case .failure(let error):
                     print("Failed to fetch activity logs: \(error)")
                     // Handle error (e.g., show an alert to the user)
                 }
             }
         }
     }
    
    
    private func fetchFullPodDetails() {
        networkManager.fetchFullPodDetails(email: viewModel.email, podId: pod.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fullPod):
                    self.pod = fullPod
                    self.reorderedItems = fullPod.items
                    // Preload videos after fetching pod details
//                    self.videoPreloader.preloadVideos(for: self.reorderedItems)
                    self.podColumns = fullPod.columns
                    self.visibleColumns = fullPod.visibleColumns
                    self.currentTitle = fullPod.title
                    self.currentDescription = fullPod.description ?? ""
                    self.currentType = fullPod.type ?? ""
                    print("Pod details fetched successfully!")
                    
                    // Wait for at least the first video to be preloaded
//                    self.waitForInitialPreload()
                
                case .failure(let error):
                    print("Failed to load pod details: \(error.localizedDescription)")
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
            // Insert the new log at the correct position
            let insertionIndex = self.activityLogs.firstIndex(where: { $0.loggedAt < newLog.loggedAt }) ?? self.activityLogs.endIndex
            self.activityLogs.insert(newLog, at: insertionIndex)
            
            // Ensure the logs are sorted
            self.activityLogs.sort()
            
            // Optionally, limit the number of logs kept in memory
            if self.activityLogs.count > 100 {
                self.activityLogs = Array(self.activityLogs.prefix(100))
            }
            
            // Update the pod's recentActivityLogs if necessary
            self.pod.recentActivityLogs = self.activityLogs
            
           
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
                                   .onTapGesture {
                                       selectedColumnForEdit = (podColumns.firstIndex(where: { $0.name == column.name }) ?? 0, column.name)
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
                        iconView(for: reorderedItems[index] , index: index)
                            .onTapGesture {
                                if reorderedItems[index].videoURL != nil || reorderedItems[index].imageURL != nil {
                                    self.selection = (0, index)
                                }
                            }
                        Spacer()

                        if itemsWithRecentActivity.contains(reorderedItems[index].id) {
                                              Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 20))
                                                  .foregroundColor(.green)
                                                  .transition(.opacity)
                                          } else {
                                              Image(systemName: "plus.bubble")
                                                  .font(.system(size: 20))
                                                  .foregroundColor(colorScheme == .dark ? Color(rgb: 107,107,107) : Color(rgb:196, 198, 207))
                                                  .onTapGesture {
                                                      selectedItemIndex = index
                                                      showLogActivitySheet = true
                                                  }
                                          }
                    }
                    .padding(10)
                }

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

//    private func iconView(for item: PodItem , index: Int) -> some View {
//        Group {
//            if item.videoURL != nil || item.imageURL != nil {
//                Image(systemName: "play")
//                    .font(.system(size: 20))
//                    .foregroundColor(colorScheme == .dark ? Color(rgb: 107,107,107) : Color(rgb:196, 198, 207))
//                    .onTapGesture {
//                                     navigationPath.append(NavigationDestination.player(items: reorderedItems, initialIndex: index))
//                                 }
//            } else {
//                Image(systemName: "camera")
//                    .font(.system(size: 20))
//                    .foregroundColor(colorScheme == .dark ? Color(rgb: 107,107,107) : Color(rgb:196, 198, 207))
//                    .onTapGesture {
//                                       selectedItemForMedia = item
//                                       showCameraView = true
//                                   }
//            }
//        }
//    }


    
    private func columnView(name: String, item: PodItem) -> some View {
        let value = item.userColumnValues?[name] ?? item.defaultColumnValues?[name] ?? .null
        return VStack {
            switch value {
            case .string(let stringValue):
                Text("\(stringValue) \(name)")
                    .font(.system(size: 14))
            case .number(let numberValue):
                Text("\(numberValue) \(name)")
                    .font(.system(size: 14))
            case .time(let timeValue):
                        Text("\(timeValue.toString) \(name)")
                            .font(.system(size: 14))
            case .null:
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
        isAddInputLoading = true
        let newItemColumnValues: [String: ColumnValue] = pod.columns.reduce(into: [:]) { result, column in
            result[column.name] = .null  // Initialize all columns with null values
        }
        
        networkManager.createPodItem(
            podId: pod.id,
            label: newItemText,
            itemType: nil,  // We're not setting an item type for now
            notes: "",
            defaultColumnValues: newItemColumnValues
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
                    // You might want to show an alert to the user here
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
                
                // View/Filter/Search section
//                HStack(spacing: 10) {
//                    viewSection
//                    filterSection
//                    Spacer()
//                    searchSection
//                }
//                .padding(.horizontal)
//                .padding(.top, 10)
//                .padding(.bottom, 15)
            }
            .background(colorScheme == .dark ? Color(rgb: 14,14,14) : .white)
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
           } else if columnType == "number", let numberValue = Int(textValue) {
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
        switch columnValue {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .time(let timeValue):
                return timeValue.toString
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
    @Binding var item: PodItem
    @Binding var podColumns: [PodColumn]
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var itemName: String
    @State private var columnValues: [String: String]
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
    
    @Binding var visibleColumns: [String]
    
    init(item: Binding<PodItem>, podId: Int, podColumns: Binding<[PodColumn]>, networkManager: NetworkManager,  allItems: Binding<[PodItem]>, visibleColumns: Binding<[String]>) {
        self._item = item
        self._itemName = State(initialValue: item.wrappedValue.metadata)
        self._podColumns = podColumns
        self.networkManager = networkManager
        self._allItems = allItems
        
        var initialColumnValues: [String: String] = [:]
        for column in podColumns.wrappedValue {
            if let value = item.wrappedValue.columnValues?[column.name] {
                switch value {
                case .string(let str): initialColumnValues[column.name] = str
                case .number(let num): initialColumnValues[column.name] = String(num)
                case .time(let timeValue): initialColumnValues[column.name] = timeValue.toString
                case .null: initialColumnValues[column.name] = ""
                }
            } else {
                initialColumnValues[column.name] = ""
            }
        }
        self._columnValues = State(initialValue: initialColumnValues)
        self.podId = podId
        self._itemNotes = State(initialValue: item.wrappedValue.notes ?? "")
        self._visibleColumns = visibleColumns
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    (colorScheme == .dark ? Color(rgb: 14,14,14) : .white)
                        .edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        
                        VStack(alignment: .leading, spacing: 20) {
                            TextField("Item Name", text: $itemName)
                                .font(.system(size: 18)).bold()
                                .background(Color.clear)
                                .focused($isItemNameFocused)
                            
                            ForEach(podColumns, id: \.name) { column in
                                VStack(alignment: .leading) {
                                    Text(column.name)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 5)
                                        .kerning(0.2)
                                    
                                    if column.type == "text" {
                                        TextField("", text: Binding(
                                            get: { self.columnValues[column.name] ?? "" },
                                            set: { self.columnValues[column.name] = $0 }
                                        ))
                                        .foregroundColor(.primary)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(.vertical, 12)
                                        .padding(.horizontal)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:218,222,237), lineWidth: colorScheme == .dark ? 1 : 1)
                                        )
                                    } else if column.type == "number" {
                                        Button(action: {
                                            withAnimation {
                                                if expandedColumn == column.name {
                                                    expandedColumn = nil
                                                } else {
                                                    expandedColumn = column.name
                                                }
                                            }
                                        }) {
                                            Text(self.columnValues[column.name] ?? "")
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:218,222,237), lineWidth: colorScheme == .dark ? 1 : 1)
                                                )
                                        }
                                        
                                        if expandedColumn == column.name {
                                            InlineNumberPicker(value: Binding(
                                                get: { Int(self.columnValues[column.name] ?? "0") ?? 0 },
                                                set: { self.columnValues[column.name] = String($0) }
                                            ))
                                            .frame(height: 150)
                                            .transition(.opacity)
                                        }
                                    } else if column.type == "time" {
                                        Button(action: {
                                            withAnimation {
                                                if expandedColumn == column.name {
                                                    expandedColumn = nil
                                                } else {
                                                    expandedColumn = column.name
                                                }
                                            }
                                        }) {
                                            Text(self.columnValues[column.name] ?? "")
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:218,222,237), lineWidth: colorScheme == .dark ? 1 : 1)
                                                )
                                        }
                                        
                                        if expandedColumn == column.name {
                                            InlineTimePicker(timeValue: Binding(
                                                get: {
                                                    TimeValue.fromString(self.columnValues[column.name] ?? "00:00:00") ??
                                                        TimeValue(hours: 0, minutes: 0, seconds: 0)
                                                },
                                                set: { newValue in
                                                    self.columnValues[column.name] = newValue.toString
                                                }
                                            ))
                                            .frame(height: 150)
                                            .transition(.opacity)
                                        }
                                    }
                                }
                            }
                            VStack(alignment: .leading) {
                                Text("Description")
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 5)
                                    .kerning(0.2)
                                
                                
                                CustomTextEditor(text: $itemNotes, backgroundColor: UIColor(colorScheme == .dark ? Color(rgb: 14,14,14) : .white))
                                    .frame(height: 100)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:218,222,237), lineWidth: 1)
                                    )

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
                
                
                .navigationBarItems(
                    leading: Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        saveChanges()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    },
                    trailing: Button(action: {
                        showItemOptions = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.primary)
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
        
        networkManager.createPodItem(podId: podId, label: newItem.metadata, itemType: newItem.itemType, notes: newItem.notes, defaultColumnValues: newItem.columnValues ?? [:]) { result in
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
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .regular))
                    Text("Add column")
                        .font(.system(size: 14, weight: .regular))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 15)
                .background(colorScheme == .dark ? Color(rgb: 14, 14, 14) : .white)
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
        newColumnName = title
        newColumnType = type // This should be "number" or "text"
        isAddingColumn = true
        showAddColumn = false
        
        networkManager.addColumnToPod(podId: podId, columnName: newColumnName, columnType: newColumnType) { result in
            DispatchQueue.main.async {
                isAddingColumn = false
                switch result {
                case .success:
                    let newColumn = PodColumn(name: newColumnName, type: newColumnType)
                    podColumns.append(newColumn)
                    
                    columnValues[newColumnName] = ""
                    
                    if item.columnValues == nil {
                        item.columnValues = [:]
                    }
                    item.columnValues?[newColumnName] = .null
                    
                    // Automatically make the new column visible if there are fewer than 3 visible columns
                                       // and this is one of the first three columns being added
//                                       if visibleColumns.isEmpty && podColumns.count <= 3 {
//                                           visibleColumns.append(newColumnName)
//                                           updateVisibleColumnsOnServer()
//                                       }
                    print("New column added successfully with type: \(newColumnType)")
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
        
        for (key, value) in columnValues {
            if let originalValue = item.columnValues?[key] {
                switch originalValue {
                case .string(let originalStringValue):
                    if originalStringValue != value {
                        updatedColumnValues[key] = .string(value)
                        hasChanges = true
                    } else {
                        updatedColumnValues[key] = originalValue
                    }
                case .number(let originalNumberValue):
                    if let intValue = Int(value), originalNumberValue != intValue {
                        updatedColumnValues[key] = .number(intValue)
                        hasChanges = true
                    } else {
                        updatedColumnValues[key] = originalValue
                    }
                case .time(let originalTimeValue):
                    if let timeValue = TimeValue.fromString(value), originalTimeValue != timeValue {
                        updatedColumnValues[key] = .time(timeValue)
                        hasChanges = true
                    } else {
                        updatedColumnValues[key] = originalValue
                    }
                case .null:
                    if !value.isEmpty {
                        // Try to parse as time first
                        if let timeValue = TimeValue.fromString(value) {
                            updatedColumnValues[key] = .time(timeValue)
                            hasChanges = true
                        } else if let intValue = Int(value) {
                            updatedColumnValues[key] = .number(intValue)
                            hasChanges = true
                        } else {
                            updatedColumnValues[key] = .string(value)
                            hasChanges = true
                        }
                    } else {
                        updatedColumnValues[key] = originalValue
                    }
                }
            } else {
                // Try to parse as time first
                if let timeValue = TimeValue.fromString(value) {
                    updatedColumnValues[key] = .time(timeValue)
                    hasChanges = true
                } else if let intValue = Int(value) {
                    updatedColumnValues[key] = .number(intValue)
                    hasChanges = true
                } else if !value.isEmpty {
                    updatedColumnValues[key] = .string(value)
                    hasChanges = true
                } else {
                    updatedColumnValues[key] = .null
                }
            }
        }
        
        // Rest of the method remains the same
        if itemName != item.metadata || itemNotes != (item.notes ?? "") {
            hasChanges = true
        }
        
        if hasChanges {
            networkManager.updatePodItem(itemId: item.id, newLabel: itemName, newNotes: itemNotes, newColumnValues: updatedColumnValues, userEmail: viewModel.email) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.item.metadata = self.itemName
                        self.item.notes = self.itemNotes
                        self.item.columnValues = updatedColumnValues
                    case .failure(let error):
                        print("Failed to update pod item: \(error)")
                    }
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        } else {
            self.presentationMode.wrappedValue.dismiss()
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

    init(item: PodItem, podColumns: [PodColumn], podId: Int,  onActivityLogged: @escaping (PodItemActivityLog) -> Void) {
        self.item = item
        self.podColumns = podColumns
        self.podId = podId
        self.onActivityLogged = onActivityLogged
        _columnValues = State(initialValue: item.columnValues ?? [:])
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
                        ForEach(podColumns, id: \.name) { column in
                            if !skippedColumns.contains(column.name) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(column.name)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 5)
                                            .kerning(0.2)
                                        
                                        Spacer()
                                        
                                        Button("Skip") {
                                            withAnimation {
                                                skippedColumns.insert(column.name)
                                                columnValues[column.name] = .null
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .font(.system(size: 13))
                                        .foregroundColor(.red)
                                    }
                                    
                                    if column.type == "text" {
                                        TextField("", text: Binding(
                                            get: { self.stringValue(for: column.name) },
                                            set: { self.columnValues[column.name] = .string($0) }
                                        ))
                                        .foregroundColor(.primary)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(.vertical, 12)
                                        .padding(.horizontal)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:218,222,237), lineWidth: 1)
                                        )
                                    } else if column.type == "number" {
                                        Button(action: {
                                            withAnimation {
                                                if expandedColumn == column.name {
                                                    expandedColumn = nil
                                                } else {
                                                    expandedColumn = column.name
                                                }
                                            }
                                        }) {
                                            Text(self.stringValue(for: column.name))
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:218,222,237), lineWidth: 1)
                                                )
                                        }
                                        
                                        if expandedColumn == column.name {
                                            InlineNumberPicker(value: Binding(
                                                get: { self.numberValue(for: column.name) },
                                                set: { self.columnValues[column.name] = .number($0) }
                                            ))
                                            .frame(height: 150)
                                            .transition(.opacity)
                                        }
                                    } else if column.type == "time" {
                                        Button(action: {
                                            withAnimation {
                                                if expandedColumn == column.name {
                                                    expandedColumn = nil
                                                } else {
                                                    expandedColumn = column.name
                                                }
                                            }
                                        }) {
                                            Text(self.stringValue(for: column.name))
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 12)
                                                .padding(.horizontal)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:218,222,237), lineWidth: 1)
                                                )
                                        }
                                        
                                        if expandedColumn == column.name {
                                            InlineTimePicker(timeValue: Binding(
                                                get: { self.timeValue(for: column.name) },
                                                set: { newValue in
                                                    self.columnValues[column.name] = .time(newValue)
                                                }
                                            ))
                                            .frame(height: 150)
                                            .transition(.opacity)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Notes section
                    if showNotesInput {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Notes")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 5)
                                .kerning(0.2)
                            
                            CustomTextEditor(text: $activityNote, backgroundColor: UIColor(Color("mxdBg")))
                                .frame(height: 100)
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(colorScheme == .dark ? Color(rgb: 44,44,44) : Color(rgb:218,222,237), lineWidth: 1)
                                )
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                showNotesInput = true
                            }
                        }) {
                            Text("+ Add notes")
                                .foregroundColor(.accentColor)
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
            .background(Color("mxdBg").edgesIgnoringSafeArea(.all)) // Apply background color
            .navigationTitle("Log Activity")
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
                }
                .foregroundColor(Color.accentColor)
            )
        }
    }
//
//    private func stringValue(for columnName: String) -> String {
//        switch columnValues[columnName] ?? .null {
//        case .string(let value): return value
//        case .number(let value): return String(value)
//        case .null: return ""
//        }
//    }
    // Add these helper methods to your view:
        private func timeValue(for columnName: String) -> TimeValue {
            switch columnValues[columnName] ?? .null {
            case .time(let value):
                return value
            case .number(let seconds):
                return TimeValue.fromSeconds(seconds)
            case .string(let value):
                return TimeValue.fromString(value) ?? TimeValue(hours: 0, minutes: 0, seconds: 0)
            case .null:
                return TimeValue(hours: 0, minutes: 0, seconds: 0)
            }
        }

        // Update your existing stringValue method:
        private func stringValue(for columnName: String) -> String {
            switch columnValues[columnName] ?? .null {
            case .string(let value):
                return value
            case .number(let value):
                return String(value)
            case .time(let value):
                return value.toString
            case .null:
                return ""
            }
        }

    private func numberValue(for columnName: String) -> Int {
        switch columnValues[columnName] ?? .null {
        case .number(let value): return value
        default: return 0
        }
    }

    private func submitActivity() {
        isSubmitting = true
        NetworkManager().createActivityLog(
            itemId: item.id,
            podId: podId,
            userEmail: viewModel.email,
            columnValues: columnValues,
//            podColumns: podColumns,
            podColumns: podColumns.filter { !skippedColumns.contains($0.name) },
            notes: activityNote
        ) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success(let newLog):
                    print("Activity logged successfully")
                    onActivityLogged(newLog)
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    print("Failed to log activity: \(error)")
                    errorMessage = error.localizedDescription
                }
            }
        }
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
