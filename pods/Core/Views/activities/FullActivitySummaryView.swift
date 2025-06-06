import SwiftUI

struct FullActivitySummaryView: View {
    let activityId: Int  // Changed to activityId
    let columns: [PodColumn]
    @EnvironmentObject var activityManager: ActivityManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showEditSheet = false
    @State private var currentActivity: Activity?
    // Add a refresh ID to force view updates
    @State private var refreshID = UUID()
    

    var body: some View {
        ZStack {
            Color("iosbg")
                .ignoresSafeArea()
            
            if let activity = currentActivity {  // Use optional binding
                ScrollView {
                    VStack(spacing: 10) {
                        // MARK: - List of Items
                        ForEach(activity.items.filter({ !shouldHideItem($0) }), id: \.id) { item in
                            // 1) The item's title *outside* the card
                            Text(item.itemLabel)
                                .font(.system(size: 18))
                                .fontWeight(.semibold)
                                .lineLimit(2)
                                .fontDesign(.rounded)
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.top)
                            
                            // 2) The "card" is just the column values
                            VStack(alignment: .leading, spacing: 10) {
                                columnValuesGrid(for: item)
                            }
                            .padding()
                            .background(Color("iosnp"))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }

                        // MARK: - Notes Section
                        if let notes = activity.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Notes")
                                    .font(.system(size: 24, weight: .bold))
                                
                                Text(notes)
                                    .font(.system(size: 16))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color("iosnp"))
                                    .cornerRadius(12)
                            }
                            .padding(20)
                        }
                    }
                    .padding(.vertical, 10)
                    // Add the refreshID to force view updates
                    .id(refreshID)
                }
                .navigationTitle(formattedDate(activity.loggedAt))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // ToolbarItem(placement: .navigationBarLeading) {
                    //     Button("Force Refresh") {
                    //         // Force a completely new activity fetch and UI rebuild
                    //         currentActivity = nil
                    //         fetchRemoteActivity()
                    //     }
                    // }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete Activity", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color("schbg"))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14))
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showEditSheet) {
                    FullEditActivityView(
                        activity: activity,
                        columns: columns
                    )
                    .onDisappear {
                        // Force a fresh data fetch when edit sheet is dismissed
                        fetchRemoteActivity()
                    }
                }
            } else {
                // Show loading indicator if activity not loaded yet
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
            }
        }
        .onAppear {
            // Try to immediately load cached data first
            loadActivity()
            
            // Then fetch fresh data in the background
            fetchRemoteActivity(skipSettingNil: true)
        }
        .onChange(of: activityManager.activities) { _ in
            // Update from local state whenever activities change
            print("ONCHANGE - ActivityManager.activities changed")
            if let updatedActivity = activityManager.activities.first(where: { $0.id == activityId }) {
                // Create a completely fresh copy by going through JSON
                do {
                    let jsonData = try JSONEncoder().encode(updatedActivity)
                    let freshCopy = try JSONDecoder().decode(Activity.self, from: jsonData)
                    print("ONCHANGE - Created fresh copy of activity \(freshCopy.id)")
                    
                    // Update on main thread
                    DispatchQueue.main.async {
                        self.currentActivity = freshCopy
                        self.refreshID = UUID() // Force UI refresh
                        print("ONCHANGE - Updated currentActivity from activityManager: \(freshCopy.id)")
                    }
                } catch {
                    print("ONCHANGE - Error creating fresh copy: \(error)")
                    // Fall back to direct assignment if JSON conversion fails
                    DispatchQueue.main.async {
                        self.currentActivity = updatedActivity
                        self.refreshID = UUID() // Force UI refresh
                        print("ONCHANGE - Updated currentActivity from activityManager (direct assignment): \(updatedActivity.id)")
                    }
                }
            } else if currentActivity == nil {
                loadActivity()
            }
        }
        .alert("Delete Activity", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let activity = currentActivity {
                    activityManager.deleteActivity(activity)
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this activity?")
        }
    }
    
    // New method to explicitly fetch from the backend
    private func fetchRemoteActivity(skipSettingNil: Bool = false) {
        print("FETCH REMOTE ACTIVITY - Starting fresh fetch for activity ID: \(activityId)")
        
        if !skipSettingNil {
            self.currentActivity = nil
        }
        
        activityManager.fetchSingleActivity(activityId: activityId) { result in
            switch result {
            case .success(let updatedActivity):
                // We now have the latest version of this activity
                print("FETCH REMOTE ACTIVITY - Successfully fetched fresh data for \(updatedActivity.id)")
                
                // Generate new UUID first
                self.refreshID = UUID()
                
                // CRITICAL: Create a completely fresh Activity object with a direct assignment
                // This ensures no chance of reference issues
                DispatchQueue.main.async {
                    // Only update if we actually have an activity with data that's different
                    // from what's currently displayed
                    if skipSettingNil && self.currentActivity != nil {
                        // Compare the timestamp or a key field to check if data is different
                        if let current = self.currentActivity, self.activityHasChanged(current, updatedActivity) {
                            self.currentActivity = updatedActivity
                            print("FETCH REMOTE ACTIVITY - Updated with fresh data (different from cache)")
                        } else {
                            print("FETCH REMOTE ACTIVITY - No update needed (same as cached)")
                        }
                    } else {
                        self.currentActivity = updatedActivity
                    }
                    
                    // Debug column values for each item
                    for item in updatedActivity.items {
                        print("DEBUG - Item \(item.id) column values after refresh: \(item.columnValues.keys)")
                        for (key, value) in item.columnValues {
                            print("DEBUG - Column \(key) value: \(value)")
                        }
                    }
                }
                
            case .failure(let error):
                print("Failed to fetch activity from server: \(error)")
                // Fall back to local state
                loadActivity()
            }
        }
    }
    
    // Create a dedicated function to load activity data from local state
    private func loadActivity() {
        print("LOAD ACTIVITY - Loading from local activities array")
        if let cachedActivity = activityManager.activities.first(where: { $0.id == activityId }) {
            // Found in cache - use directly for immediate display
            DispatchQueue.main.async {
                self.currentActivity = cachedActivity
                print("LOAD ACTIVITY - Displayed cached activity \(cachedActivity.id)")
            }
        } else {
            // If not found in current activities, try to fetch it
            print("LOAD ACTIVITY - Activity \(activityId) not found in cache, requesting from network")
            fetchRemoteActivity() // Will show loader
        }
    }

    // Helper method to determine if activity data has changed
    private func activityHasChanged(_ current: Activity, _ updated: Activity) -> Bool {
        // Check if any of the items have different column values
        if current.items.count != updated.items.count {
            return true
        }
        
        // Check each item
        for (index, currentItem) in current.items.enumerated() {
            if index >= updated.items.count {
                return true
            }
            
            let updatedItem = updated.items[index]
            
            // Check if the column values have changed
            if currentItem.columnValues.keys != updatedItem.columnValues.keys {
                return true
            }
            
            // Check each column value
            for (key, currentValue) in currentItem.columnValues {
                guard let updatedValue = updatedItem.columnValues[key] else {
                    return true
                }
                
                if !columnValuesAreEqual(currentValue, updatedValue) {
                    return true
                }
            }
        }
        
        // Check if notes or any other important fields have changed
        if current.notes != updated.notes {
            return true
        }
        
        return false
    }
    
    // Helper to compare column values
    private func columnValuesAreEqual(_ lhs: ColumnValue, _ rhs: ColumnValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let str1), .string(let str2)):
            return str1 == str2
        case (.number(let num1), .number(let num2)):
            return num1 == num2
        case (.time(let time1), .time(let time2)):
            return time1 == time2
        case (.array(let arr1), .array(let arr2)):
            guard arr1.count == arr2.count else { return false }
            for (i, value1) in arr1.enumerated() {
                if !columnValuesAreEqual(value1, arr2[i]) {
                    return false
                }
            }
            return true
        case (.null, .null):
            return true
        default:
            return false
        }
    }
}

// MARK: - Column Values Grid
extension FullActivitySummaryView {
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

    private func columnValuesGrid(for item: ActivityItem) -> some View {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singleColumns = columns.filter { $0.groupingType == "singular" }
        

        
        // CRITICAL DEBUG - Print the actual values about to be displayed
  
        for (key, value) in item.columnValues {
           
        }

        // Create a mapping between column IDs and their values for easier lookup
        let columnValues = item.columnValues

        return VStack(alignment: .leading, spacing: 24) {
            // MARK: - Grouped columns
            if !groupedColumns.isEmpty {
                // Check if any grouped column has values
                let hasGroupedValues = groupedColumns.contains { column in
                    let columnIdStr = String(column.id)
                    if let value = columnValues[columnIdStr], case .array(let arr) = value, !arr.isEmpty {
                        return true
                    }
                    return false
                }
                
                if hasGroupedValues || !columnValues.isEmpty {
                    VStack(spacing: 0) {
                        // Headers - using the order from the columns array
                        HStack(spacing: 65) {
                            ForEach(groupedColumns, id: \.id) { column in
                                Text(column.name)
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        
                        // Find the column IDs that actually exist in the item's values
                        let existingColumnKeys = groupedColumns.compactMap { column -> (Int, String)? in
                            let columnIdStr = String(column.id)
                            if columnValues[columnIdStr] != nil {
                                return (column.id, columnIdStr)
                            }
                            return nil
                        }
                        
                        if !existingColumnKeys.isEmpty {
                            // Determine the maximum number of rows
                            let maxRows = existingColumnKeys.compactMap { _, key in
                                if case .array(let values) = columnValues[key] {
                                    return values.count
                                }
                                return 0
                            }.max() ?? 0
                            
                            // Display each row using the columns we found values for
                            ForEach(0..<maxRows, id: \.self) { rowIndex in
                                HStack(spacing: 65) {
                                    ForEach(groupedColumns, id: \.id) { column in
                                        let columnId = String(column.id)
                                        
                                        if case .array(let values) = columnValues[columnId],
                                           rowIndex < values.count {
                                            Text(valueString(for: values[rowIndex]))
                                                .font(.system(size: 28, weight: .medium, design: .rounded))
                                                .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
                                                .frame(maxWidth: .infinity)
                                                .multilineTextAlignment(.center)
                                        } else {
                                            Text("-")
                                                .font(.system(size: 28, weight: .medium, design: .rounded))
                                                .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
                                                .frame(maxWidth: .infinity)
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                }
                            }
                        } else {
                            // If we couldn't find any matching columns, try a different approach
                            // Use the keys from the item's columnValues directly
                            let keys = Array(columnValues.keys)
                            
                            // Find keys with array values
                            let arrayValueKeys = keys.compactMap { key -> (String, [ColumnValue])? in
                                if case .array(let values) = columnValues[key], !values.isEmpty {
                                    return (key, values)
                                }
                                return nil
                            }
                            
                            if !arrayValueKeys.isEmpty {
                                let maxRows = arrayValueKeys.map { $0.1.count }.max() ?? 0
                                
                                ForEach(0..<maxRows, id: \.self) { rowIndex in
                                    HStack(spacing: 65) {
                                        ForEach(0..<arrayValueKeys.count, id: \.self) { keyIndex in
                                            let (_, values) = arrayValueKeys[keyIndex]
                                            
                                            if rowIndex < values.count {
                                                Text(valueString(for: values[rowIndex]))
                                                    .font(.system(size: 28, weight: .medium, design: .rounded))
                                                    .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
                                                    .frame(maxWidth: .infinity)
                                                    .multilineTextAlignment(.center)
                                            } else {
                                                Text("-")
                                                    .font(.system(size: 28, weight: .medium, design: .rounded))
                                                    .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
                                                    .frame(maxWidth: .infinity)
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                    }
                                }
                            } else {
                                Text("No values available")
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    }
                } else {
                    Text("No values available")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            
            // MARK: - Single columns
            let hasSingleValues = singleColumns.contains { column in
                let columnId = String(column.id)
                let value = columnValues[columnId]
                if case .array = value {
                    return false
                }
                if case .null = value {
                    return false
                }
                return value != nil
            }
            
            if hasSingleValues {
                ForEach(0..<(singleColumns.count + 1) / 2, id: \.self) { rowIndex in
                    HStack(spacing: 20) {
                        ForEach(0..<2) { columnIndex in
                            let index = rowIndex * 2 + columnIndex
                            if index < singleColumns.count {
                                let column = singleColumns[index]
                                let columnId = String(column.id)
                                
                                if let value = columnValues[columnId] {
                                    if case .null = value {
                                        // Skip null values
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(column.name)
                                                .font(.system(size: 18))
                                                .foregroundColor(.primary)
                                            
                                            Text(valueString(for: value))
                                                .font(.system(size: 28, weight: .medium, design: .rounded))
                                                .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
            } else if !columnValues.isEmpty {
                // Try to display single values based on keys in columnValues
                let singleValueKeys = columnValues.keys.filter { key in
                    if case .array = columnValues[key] {
                        return false
                    }
                    if case .null = columnValues[key] {
                        return false 
                    }
                    return true
                }
                
                if !singleValueKeys.isEmpty {
                    ForEach(0..<(singleValueKeys.count + 1) / 2, id: \.self) { rowIndex in
                        HStack(spacing: 20) {
                            ForEach(0..<2) { columnIndex in
                                let index = rowIndex * 2 + columnIndex
                                if index < singleValueKeys.count {
                                    let key = singleValueKeys[index]
                                    if let value = columnValues[key], case .null = value {
                                        // Skip null values
                                    } else if let value = columnValues[key] {
                                        VStack(alignment: .leading, spacing: 4) {
                                            // Try to find a matching column name
                                            let columnName = columns.first { String($0.id) == key }?.name ?? key
                                            
                                            Text(columnName)
                                                .font(.system(size: 18))
                                                .foregroundColor(.primary)
                                            
                                            Text(valueString(for: value))
                                                .font(.system(size: 28, weight: .medium, design: .rounded))
                                                .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func valueString(for value: ColumnValue) -> String {
        switch value {
        case .string(let str):
            return str
        case .number(let num):
            if floor(num) == num {
                return String(format: "%.0f", num)
            } else {
                return "\(num)"
            }
        case .time(let timeValue):
            return timeValue.toString
        case .array(let array):
            return array.map { element in
                if case let .number(num) = element, floor(num) == num {
                    return String(format: "%.0f", num)
                }
                return "\(element)"
            }.joined(separator: ", ")
        case .null:
            return ""
        }
    }
}

// MARK: - Date Formatting
extension FullActivitySummaryView {
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today, \(formatMonthDay(date)), \(formatYear(date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(formatMonthDay(date)), \(formatYear(date))"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            return "\(weekdayFormatter.string(from: date)), \(formatMonthDay(date)), \(formatYear(date))"
        } else {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            return "\(weekdayFormatter.string(from: date)), \(formatMonthDay(date)), \(formatYear(date))"
        }
    }

    private func formatMonthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
}
