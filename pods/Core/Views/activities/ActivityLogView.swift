//
//import SwiftUI
//struct ActivityLogView: View {
////    @ObservedObject var activityManager: ActivityManager
//    @EnvironmentObject var activityManager: ActivityManager
//
//    @State private var searchText: String = ""
//    @State private var selectedTab = 0
//    @State private var isInitialized = false
//
//    let columns: [PodColumn]
//    let podId: Int
//    let userEmail: String
//
//    var body: some View {
//        List {
//            // MARK: - Segmented Picker
//
//                Picker("View", selection: $selectedTab) {
//                    Text("Activities").tag(0)
//                    Text("Items").tag(1)
//                }
//                .padding(.bottom)
//                .padding(.horizontal)
//                .pickerStyle(.segmented)
//                .listRowInsets(EdgeInsets())
//                .listRowSeparator(.hidden)
//
//
//            // MARK: - Main content
//            if selectedTab == 0 {
//                // Activities section
//
//                    ForEach(filteredActivities) { activity in
//                        NavigationLink(
////                            value: NavigationDestination.fullSummary(
////                                items: activity.items.map { PodItem(from: $0) },
////                                columns: columns
////                            )
//                            value: NavigationDestination.fullActivitySummary(
//                                      activity: activity,
//                                      columns: columns
//                                  )
//                        ) {
//                            ActivityRow(activity: activity)
//                        }
//                        .padding()
//                        .id(activity.id)
//                        .listRowInsets(EdgeInsets())
//                        .onAppear {
//                            // Infinite scrolling
//                            if let last = filteredActivities.last,
//                               activity.id == last.id,
//                               !activityManager.isLoading,
//                               activityManager.hasMore {
//                                Task {
//                                    await MainActor.run {
//                                        activityManager.loadMoreActivities()
//                                    }
//                                }
//                            }
//                        }
//                        // Delete support
//                    }
//                    .onDelete { indexSet in
//                        for index in indexSet {
//                            activityManager.deleteActivity(filteredActivities[index])
//                        }
//                    }
//
//                    // Show loader at the bottom
//                    if activityManager.isLoading {
//                        ProgressView()
//                            .frame(maxWidth: .infinity)
//                    }
//
//            } else {
//
//                    ForEach(filteredItems) { item in
//                        NavigationLink(
//                            value: NavigationDestination.fullSummary(
//                                items: [PodItem(from: item)],
//                                columns: columns
//                            )
//                        ) {
//                            ItemRow(item: item)
//                        }
//                        .padding(.horizontal)
//                        .padding(.vertical, 8)
//                        .id(item.id)
//                        .listRowInsets(EdgeInsets())
//                        .onAppear {
//                            // Infinite scrolling
//                            if let last = filteredItems.last,
//                               item.id == last.id,
//                               !singleItemManager.isLoading,
//                               singleItemManager.hasMore {
//                                Task {
//                                    await MainActor.run {
//                                        singleItemManager.loadMoreItems()
//                                    }
//                                }
//                            }
//                        }
//                        // Delete support
//                    }
//                    .onDelete { indexSet in
//                        for index in indexSet {
//                            singleItemManager.deleteItem(filteredItems[index])
//                        }
//                    }
//
//                    // Show loader at the bottom
//                    if singleItemManager.isLoading {
//                        ProgressView()
//                            .frame(maxWidth: .infinity)
//                    }
//
//            }
//        }
//        .listStyle(.plain)
//        // So the title collapses on scroll
//        .navigationTitle("Logs")
//        .navigationBarTitleDisplayMode(.large)
//        // Put the search field in the navigation bar
//        .searchable(
//            text: $searchText,
//            placement: .navigationBarDrawer(displayMode: .always),
//            prompt: "Search"
//        )
//        // Pull-to-refresh
//        .refreshable {
//            await MainActor.run {
//                if selectedTab == 0 {
//                    activityManager.loadMoreActivities(refresh: true)
//                } else {
//                    singleItemManager.loadMoreItems(refresh: true)
//                }
//            }
//        }
//        // Async initialization
//        .task {
//            if !isInitialized {
//                async let activity = initializeActivityManager()
//                async let items = initializeSingleItemManager()
//                _ = await [activity, items]
//                isInitialized = true
//            }
//        }
//    }
//
//    // MARK: - Initialization
//    private func initializeActivityManager() async {
//        activityManager.initialize(podId: podId, userEmail: userEmail)
//    }
//
//    private func initializeSingleItemManager() async {
//        singleItemManager.initialize(podId: podId, userEmail: userEmail)
//    }
//
//    // MARK: - Filters
//    private var filteredActivities: [Activity] {
//        if searchText.isEmpty {
//            // Exclude single items
//            return activityManager.activities.filter { !$0.isSingleItem }
//        }
//        // Exclude single items + match search text
//        return activityManager.activities.filter { activity in
//            (!activity.isSingleItem) &&
//            (
//                activity.notes?.localizedCaseInsensitiveContains(searchText) ?? false ||
//                activity.items.contains { item in
//                    item.itemLabel.localizedCaseInsensitiveContains(searchText)
//                }
//            )
//        }
//    }
//
//    private var filteredItems: [ActivityItem] {
//        if searchText.isEmpty {
//            return singleItemManager.items
//        }
//        return singleItemManager.items.filter { item in
//            item.itemLabel.localizedCaseInsensitiveContains(searchText) ||
//            item.notes?.localizedCaseInsensitiveContains(searchText) ?? false
//        }
//    }
//}
//
//// MARK: - ActivityRow
//struct ActivityRow: View {
//    let activity: Activity
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack {
//                Text("\(activity.items.count) items")
//                    .font(.headline)
//                Spacer()
//                Text(formattedDate(activity.loggedAt))
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//
//            if let notes = activity.notes, !notes.isEmpty {
//                Text(notes)
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding(.vertical, 4)
//    }
//}
//
//// MARK: - ItemRow
//struct ItemRow: View {
//    let item: ActivityItem
//
//    var body: some View {
//        HStack(alignment: .top) {
//            VStack(alignment: .leading, spacing: 5) {
//                Text(item.itemLabel)
//                    .font(.system(size: 15))
//                    .foregroundColor(.primary)
//
//                if let notes = item.notes, !notes.isEmpty {
//                    Text(notes)
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//            }
//            Spacer()
//            Text(formattedDate(item.loggedAt))
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//        }
//    }
//}
//
//// MARK: - Date Formatting
//func formattedDate(_ date: Date) -> String {
//    let calendar = Calendar.current
//    if calendar.isDateInToday(date) {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "h:mm a"
//        return formatter.string(from: date)
//    } else if calendar.isDateInYesterday(date) {
//        return "Yesterday"
//    } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "EEEE"
//        return formatter.string(from: date)
//    } else {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "MM/dd/yy"
//        return formatter.string(from: date)
//    }
//}
//
import SwiftUI

struct ActivityLogView: View {
    @EnvironmentObject var activityManager: ActivityManager
    @State private var searchText: String = ""
    @State private var selectedTab = 0
    @State private var isInitialized = false

    let columns: [PodColumn]
    let podId: Int
    let userEmail: String

    var body: some View {
        List {
            // MARK: - Segmented Picker
            Picker("View", selection: $selectedTab) {
                Text("Activities").tag(0)
                Text("Items").tag(1)
            }
            .padding(.bottom)
            .padding(.horizontal)
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            // MARK: - Main content
            if selectedTab == 0 {
                // Multi-item Activities section
                ForEach(filteredActivities) { activity in
                    NavigationLink(
                        value: NavigationDestination.fullActivitySummary(
                            activity: activity,
                            columns: columns
                        )
                    ) {
                        ActivityRow(activity: activity)
                    }
                    .padding()
                    .id(activity.id)
                    .listRowInsets(EdgeInsets())
                    .onAppear {
                        // Infinite scrolling
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
            } else {
                // Items section - showing all ActivityItems
                ForEach(filteredItems, id: \.id) { item in
                        NavigationLink(
                            value: NavigationDestination.itemSummary(
                                item: item,
                                columns: columns
                            )
                        ) {
                            ItemRow(item: item)
                        }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .id(item.id)
                    .listRowInsets(EdgeInsets())
                    .onAppear {
                        if let last = filteredItems.last,
                           item.id == last.id,
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
                        if let activity = activityManager.activities.first(where: {
                            $0.items.contains { $0.id == filteredItems[index].id }
                        }) {
                            activityManager.deleteActivity(activity)
                        }
                    }
                }
            }

            // Show loader at the bottom
            if activityManager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search"
        )
        .refreshable {
            await MainActor.run {
                activityManager.loadMoreActivities(refresh: true)
            }
        }
        .task {
            if !isInitialized {
                await initializeActivityManager()
                isInitialized = true
            }
        }
    }

    // MARK: - Initialization
    private func initializeActivityManager() async {
        activityManager.initialize(podId: podId, userEmail: userEmail)
    }

    // MARK: - Filters
    private var filteredActivities: [Activity] {
        if searchText.isEmpty {
            return activityManager.activities.filter { !$0.isSingleItem }
        }
        return activityManager.activities.filter { activity in
            (!activity.isSingleItem) &&
            (
                activity.notes?.localizedCaseInsensitiveContains(searchText) ?? false ||
                activity.items.contains { item in
                    item.itemLabel.localizedCaseInsensitiveContains(searchText)
                }
            )
        }
    }

    private func shouldHideItem(_ item: ActivityItem) -> Bool {
           guard !item.columnValues.isEmpty else { return true }
           return !item.columnValues.values.contains { value in
               switch value {
               case .null:
                   return false
               case .string(let str):
                   return !str.isEmpty
               case .number:
                   return true
               case .time(let timeValue):
                   return timeValue != TimeValue(hours: 0, minutes: 0, seconds: 0)
               case .array(let values):
                   return values.contains { val in
                       if case .null = val { return false }
                       return true
                   }
               }
           }
       }

       // Update the existing filteredItems
       private var filteredItems: [ActivityItem] {
           let allItems = activityManager.activities.flatMap { activity in
               activity.items
           }.filter { !shouldHideItem($0) }  // Apply the filter here
           
           if searchText.isEmpty {
               return allItems
           }
           
           return allItems.filter { item in
               item.itemLabel.localizedCaseInsensitiveContains(searchText) ||
               item.notes?.localizedCaseInsensitiveContains(searchText) ?? false
           }
       }
}

// MARK: - Supporting Views
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

// MARK: - Date Formatting
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


