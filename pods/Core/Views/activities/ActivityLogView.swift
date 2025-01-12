//import SwiftUI
//
//struct ActivityLogView: View {
//    @ObservedObject var manager: ActivityLogManager
//    @State private var searchText: String = ""
//    @State private var filteredLogs: [PodItemActivityLog] = []
//    let columns: [PodColumn]
//    
//    init(manager: ActivityLogManager, columns: [PodColumn]) {
//        self.manager = manager
//        self.columns = columns
//    }
//
//    var body: some View {
//        ZStack {
//            if manager.isLoading && manager.logs.isEmpty {
//                ProgressView()
//            } else {
//                List {
//                    ForEach(filteredLogs, id: \.id) { log in
//                        if let activityIndex = manager.logs.firstIndex(where: { $0.id == log.id }) {
//                            NavigationLink(value: NavigationDestination.fullActivityLog(
//                                log: Binding(
//                                    get: { manager.logs[activityIndex] },
//                                    set: { manager.updateLog(at: activityIndex, with: $0) }
//                                ),
//                                columns: columns,
//                                onLogUpdated: { updatedLog in
//                                    manager.updateLog(at: activityIndex, with: updatedLog)
//                                }
//                            )) {
//                                logRowContent(for: log)
//                            }
//                        }
//                    }
//                    .onDelete { indexSet in
//                        let logsToDelete = indexSet.map { filteredLogs[$0] }
//                        for log in logsToDelete {
//                            manager.deleteLog(log)
//                        }
//                    }
//                    .listRowBackground(Color("bg"))
//                    
//                    if !manager.isLoading && manager.hasMore {
//                        ProgressView()
//                            .frame(maxWidth: .infinity)
//                            .listRowBackground(Color.clear)
//                            .onAppear {
//                                manager.loadMoreLogs()
//                            }
//                    }
//                }
//                .listStyle(GroupedListStyle())
//                .refreshable {
//                    manager.loadMoreLogs(refresh: true)
//                }
//            }
//        }
//        .navigationTitle("Activities")
//        .navigationBarTitleDisplayMode(.large)
//        .toolbarBackground(.visible, for: .navigationBar)
//        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
//        .onChange(of: searchText) { _ in
//            updateFilteredLogs()
//        }
//        .onChange(of: manager.logs) { _ in
//            updateFilteredLogs()
//        }
//        .onAppear {
//            if manager.logs.isEmpty {
//                manager.loadMoreLogs(refresh: true)
//            }
//            updateFilteredLogs()
//        }
//    }
//    
//    private func logRowContent(for log: PodItemActivityLog) -> some View {
//        HStack(alignment: .top) {
//            VStack(alignment: .leading, spacing: 5) {
//                Text(log.itemLabel)
//                    .font(.system(size: 15))
//                    .foregroundColor(.primary)
//            }
//            
//            Spacer()
//            
//            HStack(spacing: 5) {
//                Text(formattedDate(log.loggedAt))
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .background(Color("bg"))
//    }
//    
//    private func updateFilteredLogs() {
//        if searchText.isEmpty {
//            filteredLogs = manager.logs
//        } else {
//            filteredLogs = manager.logs.filter { log in
//                log.itemLabel.localizedCaseInsensitiveContains(searchText) ||
//                log.userName.localizedCaseInsensitiveContains(searchText) ||
//                log.notes.localizedCaseInsensitiveContains(searchText)
//            }
//        }
//    }
//    
//    private func formattedDate(_ date: Date) -> String {
//        let calendar = Calendar.current
//        if calendar.isDateInToday(date) {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "h:mm a"
//            return formatter.string(from: date)
//        } else if calendar.isDateInYesterday(date) {
//            return "Yesterday"
//        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "EEEE"
//            return formatter.string(from: date)
//        } else {
//            let formatter = DateFormatter()
//            formatter.dateFormat = "MM/dd/yy"
//            return formatter.string(from: date)
//        }
//    }
//}
import SwiftUI

struct ActivityLogView: View {
    @StateObject private var activityManager = ActivityManager()
    @StateObject private var singleItemManager = SingleItemActivityManager()
    @State private var searchText: String = ""
    @State private var selectedTab = 0
    @State private var isInitialized = false
    let columns: [PodColumn]
    
    let podId: Int
    let userEmail: String
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedTab) {
                Text("Activities").tag(0)
                Text("Items").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if selectedTab == 0 {
                activitiesList
            } else {
                itemsList
            }
        }
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .task {
            if !isInitialized {
                // Initialize both managers simultaneously
                async let activity = initializeActivityManager()
                async let items = initializeSingleItemManager()
                _ = await [activity, items]
                isInitialized = true
            }
        }
    }
    
    private func initializeActivityManager() async {
        activityManager.initialize(podId: podId, userEmail: userEmail)
    }
    
    private func initializeSingleItemManager() async {
        singleItemManager.initialize(podId: podId, userEmail: userEmail)
    }
    
    private var activitiesList: some View {
        List {
            ForEach(filteredActivities) { activity in
                NavigationLink(value: NavigationDestination.fullSummary(
                    items: activity.items.map { PodItem(from: $0) },
                    columns: columns
                )) {
                    ActivityRow(activity: activity)
                }
                .id(activity.id) // Explicit ID for better list performance
                .onAppear {
                    if let last = filteredActivities.last,
                       activity.id == last.id,
                       !activityManager.isLoading,
                       activityManager.hasMore {
                        Task {
                            await MainActor.run {
                                activityManager.loadMoreActivities()
                            }
                        }
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    activityManager.deleteActivity(filteredActivities[index])
                }
            }
            
            if activityManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .refreshable {
            await MainActor.run {
                activityManager.loadMoreActivities(refresh: true)
            }
        }
    }
    
    private var itemsList: some View {
        List {
            ForEach(filteredItems) { item in
                NavigationLink(value: NavigationDestination.fullSummary(
                    items: [PodItem(from: item)],
                    columns: columns
                )) {
                    ItemRow(item: item)
                }
                .id(item.id) // Explicit ID for better list performance
                .onAppear {
                    if let last = filteredItems.last,
                       item.id == last.id,
                       !singleItemManager.isLoading,
                       singleItemManager.hasMore {
                        Task {
                            await MainActor.run {
                                singleItemManager.loadMoreItems()
                            }
                        }
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    singleItemManager.deleteItem(filteredItems[index])
                }
            }
            
            if singleItemManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .refreshable {
            await MainActor.run {
                singleItemManager.loadMoreItems(refresh: true)
            }
        }
    }
    
    @ViewBuilder
    private func loadingView() -> some View {
        if activityManager.isLoading || singleItemManager.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
        }
    }
    
    private var filteredActivities: [Activity] {
        if searchText.isEmpty {
            return activityManager.activities.filter { !$0.isSingleItem }
        }
        return activityManager.activities.filter { activity in
            (!activity.isSingleItem) &&
            (activity.notes?.localizedCaseInsensitiveContains(searchText) ?? false ||
             activity.items.contains { item in
                item.itemLabel.localizedCaseInsensitiveContains(searchText)
             })
        }
    }
    
    private var filteredItems: [ActivityItem] {
        if searchText.isEmpty {
            return singleItemManager.items
        }
        return singleItemManager.items.filter { item in
            item.itemLabel.localizedCaseInsensitiveContains(searchText) ||
            item.notes?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
}
struct ActivityRow: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(activity.items.count) items")
                    .font(.headline)
                Spacer()
                Text(formattedDate(activity.loggedAt))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let notes = activity.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ItemRow: View {
    let item: ActivityItem
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.itemLabel)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(formattedDate(item.loggedAt))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

func formattedDate(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter.string(from: date)
    }
}
