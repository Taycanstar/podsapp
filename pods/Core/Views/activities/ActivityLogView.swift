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
            Picker("View", selection: $selectedTab) {
                Text("Activities").tag(0)
                Text("Items").tag(1)
            }
      
            .padding(.bottom)
            .padding(.horizontal)
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color("iosbg"))

            // MARK: - Main content
            if selectedTab == 0 {

                ForEach(filteredActivities) { activity in
                    ZStack(alignment: .leading) {
                        NavigationLink(
                            value: AppNavigationDestination.fullActivitySummary(
                                activityId: activity.id,
                                columns: columns
                            )
                        ) {
                            EmptyView()
                        }
                      
                        .opacity(0)
                        
                        ActivityRow(activity: activity)
                    }
                     .buttonStyle(PlainButtonStyle())
                     .padding(.horizontal)
                     .padding(.vertical, 4)
                     .listRowInsets(EdgeInsets())
                     .listRowSeparator(.hidden)
                     .listRowBackground(Color("iosbg"))
                     .id(activity.id)
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
            } else {
                // Items section - showing all ActivityItems
                ForEach(filteredItems, id: \.id) { item in
                        NavigationLink(
                            value: AppNavigationDestination.itemSummary(
                                itemId: item.id,  
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
                        // Debug info to help diagnose column mismatch issues
                        if let last = filteredItems.last, item.id == last.id {
                            print("Debug - Item \(item.id) column values: \(item.columnValues.keys)")
                            print("Debug - Passing columns to ItemSummaryView: \(columns.map { "\($0.id):\($0.name)" })")
                        }
                        
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
        .scrollContentBackground(.hidden)  // Add this
        .background(Color("iosbg"))
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


//struct ActivityRow: View {
//    let activity: Activity
//    
//    private func formatDuration(_ seconds: Int) -> String {
//        let hours = seconds / 3600
//        let minutes = (seconds % 3600) / 60
//        let remainingSeconds = seconds % 60
//        
//        if hours > 0 {
//            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
//        } else {
//            return String(format: "%d:%02d", minutes, remainingSeconds)
//        }
//    }
//
//    var body: some View {
//        HStack(alignment: .center, spacing: 12) {
//            // Pod icon
//            Image("pd") // Make sure to have this image in your assets
//                .resizable()
//                .frame(width: 40, height: 40)
//                .clipShape(RoundedRectangle(cornerRadius: 8))
//            
//            // Center content
//            VStack(alignment: .leading, spacing: 4) {
//                Text(activity.podTitle)
//                    .font(.system(size: 16, weight: .regular))
//                    .foregroundColor(.primary)
//                
//                Text(formatDuration(activity.duration))
//                    .font(.system(size: 24, weight: .semibold, design: .rounded))
//                    .foregroundColor(Color("neonGreen"))
//            }
//            
//            Spacer()
//            
//            // Date
//            Text(formattedDate(activity.loggedAt))
//                .font(.subheadline)
//                .foregroundColor(.secondary)
//        }
//        .padding(.vertical, 12)
//        .padding(.horizontal, 16)
//        .background(Color(.systemBackground))
//        .clipShape(RoundedRectangle(cornerRadius: 12))
//        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
//    }
//}
struct ActivityRow: View {
    let activity: Activity
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }

    var body: some View {
        HStack(spacing: 16) {  // Increased spacing between elements
            // Pod icon
            Image("pd")
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Center content
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.podTitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                
                Text(formatDuration(activity.duration))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(Color("neonGreen"))
            }
            
            Spacer()
            
            // Date
            Text(formattedDate(activity.loggedAt))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color("iosnp"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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


