import SwiftUI
import AVFoundation
import Mixpanel

enum NavigationDestination: Hashable {
    case player(item: PodItem)
    case podInfo
    case podMembers
    case activityLog
    case trends(podId: Int)
    case fullAnalytics(column: PodColumn, activities: [Activity], itemId: Int)
    case gracie(podId: Int)
    case fullActivityLog(log: Binding<PodItemActivityLog>, columns: [PodColumn], onLogUpdated: (PodItemActivityLog) -> Void)
    case activitySummary(pod: Pod, duration: Int, startTime: Date, endTime: Date, podColumns: [PodColumn], notes: String?)
    case fullSummary(items: [PodItem], columns: [PodColumn])
    case fullActivitySummary(activityId: Int, columns: [PodColumn])
    case itemSummary(itemId: Int, columns: [PodColumn])
    
    
    
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

        case .fullAnalytics(let column, let activities, let itemId):
                    hasher.combine("fullAnalytics")
                    hasher.combine(column.name)
                    hasher.combine(itemId)
                    hasher.combine(activities.map { $0.id })
        case .gracie(let podId):
            hasher.combine("gracie")
            hasher.combine(podId)
            
        case .fullActivityLog(let log, _, _):
            hasher.combine("fullActivityLog")
            hasher.combine(log.id)
            
        case .activitySummary(let pod, let duration, let startTime, let endTime, let podColumns, let notes):
                    hasher.combine("activitySummary")
                    hasher.combine(pod.id)
                    hasher.combine(duration)
                    hasher.combine(startTime)
                    hasher.combine(endTime)
                    hasher.combine(podColumns.map { $0.id })
                    hasher.combine(notes)
        case .fullSummary(let items, let columns):
                  hasher.combine("fullSummary")
                  hasher.combine(items.map { $0.id })
            hasher.combine(columns.map { $0.id })
        case .fullActivitySummary(let activityId, let columns):
                    hasher.combine("fullActivitySummary")
                    hasher.combine(activityId)
                    hasher.combine(columns.map { $0.id })
        case .itemSummary(let itemId, let columns):
                    hasher.combine("itemSummary")
                    hasher.combine(itemId)
                    hasher.combine(columns.map { $0.id })
            
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
        case (.fullAnalytics(let column1, let activities1, let itemId1),
                      .fullAnalytics(let column2, let activities2, let itemId2)):
                    return column1.name == column2.name &&
                           activities1.map { $0.id } == activities2.map { $0.id } &&
                           itemId1 == itemId2
        case (.fullActivityLog(let log1, _, _), .fullActivityLog(let log2, _, _)):
            return log1.id == log2.id
        case (.activitySummary(let pod1, let duration1, let startTime1, let endTime1, let columns1, let notes1),
              .activitySummary(let pod2, let duration2, let startTime2, let endTime2, let columns2, let notes2)):
            return pod1.id == pod2.id &&
                   duration1 == duration2 &&
                   startTime1 == startTime2 &&
                   endTime1 == endTime2 &&
                   columns1.map { $0.id } == columns2.map { $0.id } &&
                   notes1 == notes2
                    
                case (.fullSummary(let items1, let columns1), .fullSummary(let items2, let columns2)):
                    return items1.map { $0.id } == items2.map { $0.id } &&
                           columns1.map { $0.id } == columns2.map { $0.id }
        case (.fullActivitySummary(let activityId1, let columns1),
                      .fullActivitySummary(let activityId2, let columns2)):
                    return activityId1 == activityId2 &&
                           columns1.map { $0.id } == columns2.map { $0.id }
        case (.itemSummary(let itemId1, let columns1),
                      .itemSummary(let itemId2, let columns2)):
                    return itemId1 == itemId2 &&
                           columns1.map { $0.id } == columns2.map { $0.id }
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
    @State private var isActivityOpen = false
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
    
    @State private var navigationPath = NavigationPath()
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItemForMedia: PodItem?
    @State private var showCameraView = false

    @State private var isAddInputLoading = false
    @StateObject private var videoPreloader = VideoPreloader()
    
    @State private var pendingNavigation: NavigationDestination?
    @State private var isLoading = true

    @StateObject private var logManager = ActivityLogManager()
    @StateObject private var activityManager = ActivityManager()
    @ObservedObject private var activityState = ActivityState.shared
    @State private var showCountdown = false
    
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
    
    private var hasCompleteData: Bool {
        return !pod.columns.isEmpty && !pod.items.isEmpty
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
        ZStack {
            (Color("bg"))
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {

                PodViewHeaderSection(
                                       selectedView: $selectedView,
                                       podTitle: currentTitle,
                                       showPodOptionsSheet: {
                                           showPodOptionsSheet = true
                                           Mixpanel.mainInstance().track(event: "Tapped Pod Options")
                                       },
                                       onDismiss: {
                                           if activityState.isActivityInProgress {
                                                      activityState.cancelActivity()
                                                      isActivityOpen = false
                                                  }
                                           
                                           dismiss() }  // Add this line
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

                                       }
                                   
                                       

                         
                                       .safeAreaInset(edge: .bottom) {
                                         
                                           if !isCreatingNewItem && !activityState.isActivityInProgress{
                                               footerView
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
                    .onDisappear {
                        if activityState.isActivityInProgress {
                            isActivityOpen = true
                        }
                    }
            case .podInfo:
                PodInfoView(pod: $pod,
                            currentTitle: $currentTitle,
                            currentDescription: $currentDescription,
                            currentType: $currentType, currentPrivacy: $currentType,
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
//                ActivityLogView(manager: logManager, columns: podColumns)
//                ActivityLogView(columns: podColumns, podId: pod.id, userEmail: viewModel.email)
                ActivityLogView(
                        columns: podColumns,
                        podId: pod.id,
                        userEmail: viewModel.email
                    )
            case .trends(let podId):
                ItemTrendsView(podId: podId, podItems: reorderedItems, podColumns: podColumns)
//            case .fullAnalytics(let column, let logs):
//                            FullAnalyticsView(column: column, activityLogs: logs)
            case .fullAnalytics(let column, let activities, let itemId):
                    FullAnalyticsView(
                        column: column,
                        activities: activities,
                        itemId: itemId,
                        getHighestValue: { activity in
                            let relevantItem = activity.items.first { $0.itemId == itemId }
                            guard let columnValue = relevantItem?.columnValues[String(column.id)] else { return nil }
                            
                            switch columnValue {
                            case .number(let value):
                                return value
                            case .time(let timeValue):
                                return Double(timeValue.totalSeconds)
                            case .array(let values):
                                let numericValues = values.compactMap { value -> Double? in
                                    switch value {
                                    case .number(let num): return num
                                    case .time(let time): return Double(time.totalSeconds)
                                    default: return nil
                                    }
                                }
                                return numericValues.max()
                            default:
                                return nil
                            }
                        }
                    )
            case .gracie(let podId):
                GracieView(podId: podId)

            case .fullActivityLog(let log, let columns, let onLogUpdated):
                FullActivityLogView(log: log,
                                   columns: columns,
                                   onDelete: { _ in },
                                   onUpdate: onLogUpdated)
                
            case .activitySummary(let pod, let duration, let startTime, let endTime,  let podColumns, let notes):
                    ActivitySummaryView(
                        pod: pod,
                        duration: duration,
                        items: reorderedItems,
                        startTime: startTime,
                        endTime: endTime,
                        podColumns: podColumns,
                        navigationAction: { destination in
                                    navigationPath.append(destination)
                                },
                        notes: notes
                    )
            case .fullSummary(let items, let columns):
                FullSummaryView(items: items, columns: podColumns)
//            case .fullActivitySummary(let activity, let columns):
//                FullActivitySummaryView(activity: activity, columns: columns)
            case .fullActivitySummary(let activityId, let columns):
                   FullActivitySummaryView(activityId: activityId, columns: columns)
            case .itemSummary(let itemId, let columns):
                    ItemSummaryView(itemId: itemId, columns: columns)


                            
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
            

        
            
              // Only fetch if we don't have complete data
              if !hasCompleteData {
                  fetchFullPodDetails(showLoadingIndicator: true)
              } else {
                  isLoading = false  // Skip loading state if we have data
              }

            initializeManagers()
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
                let wasActivityOpen = isActivityOpen
                       isActivityOpen = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navigationPath.append(destination)
                    if wasActivityOpen {
                                   isActivityOpen = true
                               }
                }
            })
            
        }

        .sheet(isPresented: $isActivityOpen) {
            ActivityView(pod: $pod, podColumns: $podColumns, items: $reorderedItems,    onActivityFinished: { duration, startTime, endTime, notes in
                navigationPath.append(NavigationDestination.activitySummary(
                   
                    pod: pod,
                    duration: duration,
                    startTime: startTime,
                    endTime: endTime,
                    podColumns: podColumns,
                    notes: notes
                ))
            })
                .presentationDetents([.height(50), .large], selection: $activityState.sheetHeight)
                .interactiveDismissDisabled(activityState.isActivityInProgress)
                .presentationBackgroundInteraction(.enabled)  // This enables interaction with background
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
            
        .fullScreenCover(isPresented: $showCountdown) {
            ActivityCountdownView(isPresented: $showCountdown) {
                // This closure is called when countdown finishes
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
                                   self.onActivityLogged(newLog: newLog)
                        
                               }
                )
                
                    .onDisappear {
                        if activityState.isActivityInProgress {
                            isActivityOpen = true
                        }
                    }
//                .presentationDetents([.height(UIScreen.main.bounds.height / 2)])
            }
        }
        
        
    }
        .navigationBarHidden(true)
    }
    

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
//                activityState.sheetHeight = .large
//                isActivityOpen = true
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
    
    
    private func initializeManagers() {
        activityManager.initialize(podId: pod.id, userEmail: viewModel.email)
    }
    
    private func fetchFullPodDetails(showLoadingIndicator: Bool = true) {
        if showLoadingIndicator {
              isLoading = true
          }
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
          
          // Update the reorderedItems and pod.items
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
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reorderedItems[index].metadata)
                            .font(.system(size: 14))
                            .fontWeight(.regular)
//                            .padding(.bottom, 4)
                        
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
                        Spacer ()
                    
                     
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
//                    .padding(5)
                    
                   
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
//                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 15, bottom: 6, trailing: 15))
                .contentShape(Rectangle())
                .onTapGesture {
//                                                   selectedItemIndex = index
//                                                   showLogActivitySheet = true
//                                        let wasActivityOpen = isActivityOpen
//                                        isActivityOpen = false
                    
                    selectedItemIndex = index
                    showCardSheet = true
                    let wasActivityOpen = isActivityOpen
                           isActivityOpen = false
                                                   HapticFeedback.generate()
                                               }
            }
            if isCreatingNewItem {
                newItemInputView
//                    .listRowInsets(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color("bg"))
            }
            
            // Insert the new item input row here
                  
        }
        .listStyle(PlainListStyle())
        .refreshable {
            fetchFullPodDetails(showLoadingIndicator: false)
        }
        .background(Color("bg"))
    }

    private func iconView(for item: PodItem, index: Int) -> some View {
        Menu {
//            Button(action: {
//                selectedItemIndex = index
//                showCardSheet = true
//                let wasActivityOpen = isActivityOpen
//                       isActivityOpen = false
//            }) {
//                Label("Edit Item", systemImage: "square.and.pencil")
//            }
            
            if item.videoURL != nil || item.imageURL != nil {
                Button(action: {
                    navigationPath.append(NavigationDestination.player(item: item))
                    let wasActivityOpen = isActivityOpen
                    isActivityOpen = false
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
                             .frame(width: 30, height: 30) // Adjust size for breathing room
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
    @State private var showNotesInput = false
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
    @State private var logNotes: String?
    @FocusState private var focusedField: String?

    @Binding var visibleColumns: [String]
    @State private var hasUnsavedChanges = false
    @EnvironmentObject var activityManager: ActivityManager
    let podTitle: String




    @State private var groupedRowsCount: [String: Int] = [:]
    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
            let groupedColumns = columns.filter { $0.groupingType == "grouped" }
            let singularColumns = columns.filter { $0.groupingType == "singular" }
            return [groupedColumns, singularColumns].filter { !$0.isEmpty }
        }
    

    init(item: Binding<PodItem>, podId: Int,podTitle: String, podColumns: Binding<[PodColumn]>, networkManager: NetworkManager, allItems: Binding<[PodItem]>, visibleColumns: Binding<[String]>) {
        self._item = item
        self.podTitle = podTitle
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
                    
                    VStack(spacing: 0) {  // Main container
                                       ScrollView {
                                           VStack(alignment: .leading, spacing: 20) {
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
                                                               columnValues: $columnValues,
                                                               focusedField: _focusedField,
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
                                                           columnValues: $columnValues,
                                                           focusedField: _focusedField,
                                                           expandedColumn: $expandedColumn,
                                                           onValueChanged: checkForChanges
                                                       )
                                                   }
                                               }
                                               
                                               VStack(alignment: .leading) {
                                                   Text("Description")
                                                       .font(.system(size: 15))
                                                       .foregroundColor(.primary)
                                                       .padding(.horizontal, 5)
                                                       .kerning(0.2)

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
                                               
                                               if showNotesInput {
                                                   VStack(alignment: .leading) {
                                                       Text("Notes")
                                                           .font(.system(size: 15))
                                                           .foregroundColor(.primary)
                                                           .padding(.horizontal, 5)
                                                           .kerning(0.2)

                                                       CustomTextEditor(text: Binding(
                                                           get: { logNotes ?? "" },
                                                           set: {
                                                               logNotes = $0
                                                           }
                                                       ), backgroundColor: UIColor(Color("iosnp")))
                                                           .frame(height: 100)
                                                           .padding(.vertical, 8)
                                                           .padding(.horizontal)
                                                           .background(Color("iosnp"))
                                                           .cornerRadius(12)
                                                   }
                                               } else {
                                                   Button(action: {
                                                       withAnimation {
                                                           showNotesInput = true
                                                       }
                                                   }) {
                                                       Text("Add Notes")
                                                           .foregroundColor(.accentColor)
                                                   }
                                                   .frame(maxWidth: .infinity)
                                                   .padding(.top, 8)
                                               }
                                           }
                                           .padding()
                                       }
                                       
                                       // Log Single Item button fixed at bottom
                                       VStack {
                                           Button(action: {
                                               print("Log Activity tapped")
                                               logSingleItem()
                                           }) {
                                               Text("Log Single Item")
                                                   .font(.system(size: 16))
                                                   .fontWeight(.medium)
                                                   .foregroundColor(.accentColor)
                                                   .frame(maxWidth: .infinity)
                                                   .padding(.vertical, 12)
                                                   .background(Color.accentColor.opacity(0.1))
                                                   .cornerRadius(8)
                                           }
                                           .padding(.horizontal)
                                           .padding(.bottom, 16) // Add some bottom padding for better spacing
                                       }
                                       .background(Color("iosbg")) // Match the background color
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
    
    // In CardDetailView
    private func logSingleItem() {
        // Create a temporary ID
        let tempId = Int.random(in: Int.min ... -1)
        
        // Convert column values to the format expected by the backend
        let convertedValues = columnValues.mapValues { value -> Any in
            convertColumnValueToAny(value)
        }
        
        // Prepare the single item data with explicit type
        let itemData: [(id: Int, notes: String?, columnValues: [String: Any])] = [(
            id: item.id,
            notes: nil,
            columnValues: convertedValues
        )]
        
        // Step 1: Create temporary activity with the negative ID
        let tempActivity = Activity(
            id: tempId,
            podId: podId,
            podTitle: podTitle,
            userEmail: viewModel.email,
            userName: viewModel.username,
            duration: 0,
            loggedAt: Date(),
            notes: logNotes,
            isSingleItem: true,
            items: [
                ActivityItem(
                    id: Int.random(in: Int.min ... -1),
                    activityId: tempId,
                    itemId: item.id,
                    itemLabel: item.metadata,
                    loggedAt: Date(),
                    notes: Optional<String>.none,
                    columnValues: columnValues  // Use the original columnValues here, not the converted ones
                )
            ]
        )
        
        // Step 2: Insert temporary activity into ActivityManager
        activityManager.activities.insert(tempActivity, at: 0)
        print("Inserted temporary single item activity with ID: \(tempId)")
        
        // Step 3: Dismiss view immediately for optimistic update
        presentationMode.wrappedValue.dismiss()
        
        // Step 4: Make the actual network request
        activityManager.createActivity(
            duration: 0,
            notes: logNotes,
            items: itemData,
            isSingleItem: true,
            tempId: tempId
        ) { result in
            DispatchQueue.main.async {
                guard self != nil else { return }
                
                switch result {
                case .success(let actualActivity):
                    print("Single item activity creation completed.")
                    
                case .failure(let error):
                    // Remove the temporary activity
                    activityManager.activities.removeAll { $0.id == tempId }
                    print("Failed to create single item activity, removed temporary activity ID: \(tempId)")
//                    self.logError = error
//                    self.showLogError = true
                }
            }
        }
    }

    private func convertColumnValueToAny(_ value: ColumnValue) -> Any {
        switch value {
        case .string(let str):
            return str
        case .number(let num):
            return num
        case .time(let timeValue):
            return timeValue
        case .array(let arr):
            return arr.map { convertColumnValueToAny($0) }
        case .null:
            return NSNull()
        }
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
//            .padding(.vertical, 8)
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
                Text("Add Row")
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(.top, 5)
        .onAppear {
                   if groupedRowsCount == 0 {
                       onAddRow()
                   }
               }
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
                    .padding(.vertical, 8)
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
                    .padding(.vertical, 8)
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
                        .padding(.vertical, 8)
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
                    .multilineTextAlignment(.center)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 8)
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
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 8)
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
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
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
    @ObservedObject var logManager: ActivityLogManager
    var onActivityLogged: (PodItemActivityLog) -> Void
    @State private var skippedColumns: Set<String> = []
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false
    @FocusState private var focusedField: String?
    @State private var groupedRowsCount: [String: Int] = [:]
    

    init(item: PodItem, podColumns: [PodColumn], podId: Int,logManager: ActivityLogManager,  onActivityLogged: @escaping (PodItemActivityLog) -> Void) {
            self.item = item
            self.podColumns = podColumns
            self.podId = podId
        self.logManager = logManager
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
                ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text("Add Activity") // Main title
                                .font(.headline)
                            Text(item.metadata) // Subtitle (e.g., "Lat Pulldowns")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
//            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
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
                    logManager.logs.insert(newLog, at: 0) // Add at beginning since it's newest
                       logManager.cacheLogs() // Make sure it's cached
                    
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
