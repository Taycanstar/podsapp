
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
    
    // Add computed property to get fresh activity data
    // private var activity: Activity? {
        
    //     activityManager.activities.first { $0.id == activityId }
    // }
    
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
                }
                .navigationTitle(formattedDate(activity.loggedAt))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
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
                }
            }
        }
         .onAppear {
            // Load activity once when view appears
            currentActivity = activityManager.activities.first { $0.id == activityId }
        }
        .onChange(of: activityManager.activities) { _ in
            // Update if activities change
            currentActivity = activityManager.activities.first { $0.id == activityId }
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
    
    // Get sorted item column IDs to maintain consistent order
    let itemColumnIds = Array(item.columnValues.keys).sorted()


    return VStack(alignment: .leading, spacing: 24) {
        // MARK: - Grouped columns
        if !groupedColumns.isEmpty {
            VStack(spacing: 0) {
                // Headers
                HStack(spacing: 65) {
                    ForEach(groupedColumns.indices, id: \.self) { index in
                        Text(groupedColumns[index].name)
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                // Data rows
                let minLength: Int = itemColumnIds.compactMap { columnId in
                    guard case .array(let values) = item.columnValues[columnId] ?? .null
                    else { return nil }
                    return values.count
                }.min() ?? 0
                
                ForEach(0..<minLength, id: \.self) { rowIndex in
                    HStack(spacing: 65) {
                        ForEach(groupedColumns.indices, id: \.self) { columnIndex in
                            if columnIndex < itemColumnIds.count,
                               case .array(let values) = item.columnValues[itemColumnIds[columnIndex]] ?? .null {
                                Text("\(values[rowIndex])")
                                    .font(.system(size: 28, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("-")
                                    .font(.system(size: 28, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        
        // MARK: - Single columns
        ForEach(0..<(singleColumns.count + 1) / 2, id: \.self) { rowIndex in
            HStack(spacing: 20) {
                ForEach(0..<2) { columnIndex in
                    let index = rowIndex * 2 + columnIndex
                    if index < singleColumns.count {
                        let column = singleColumns[index]
                        if itemColumnIds.indices.contains(index),
                           let value = item.columnValues[itemColumnIds[index]] {
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
}
    // private func columnValuesGrid(for item: ActivityItem) -> some View {
    //         print("DEBUG: Activity ID for item \(item.id): \(currentActivity?.id ?? -1)")
    // print("DEBUG: Columns source: \(columns)")
    // print("DEBUG: Column IDs in item: \(Array(item.columnValues.keys))")
    // print("DEBUG: Expected column IDs: \(columns.map { String($0.id) })")
    //         print("DEBUG: Displaying column values for item \(item.id): \(item.columnValues)")
    // print("DEBUG: Available columns: \(columns.map { "\($0.id): \($0.name)" })")
    //     let groupedColumns = columns.filter { $0.groupingType == "grouped" }
    //     let singleColumns = columns.filter { $0.groupingType == "singular" }

    //         print("DEBUG: Grouped columns: \(groupedColumns.map { $0.id })")
    // print("DEBUG: Single columns: \(singleColumns.map { $0.id })")



    //     return VStack(alignment: .leading, spacing: 24) {
    //         // MARK: - Grouped columns
    //         if !groupedColumns.isEmpty {
    //             VStack(spacing: 0) {
    //                 // Headers
    //                 HStack(spacing: 65) {
    //                     ForEach(groupedColumns, id: \.id) { column in
    //                         Text(column.name)
    //                             .font(.system(size: 18))
    //                             .foregroundColor(.primary)
    //                             .frame(maxWidth: .infinity, alignment: .center)
    //                     }
    //                 }
                    
    //                 // Data rows
    //                 let minLength: Int = groupedColumns.compactMap { column in
    //                     guard case .array(let values) = item.columnValues[String(column.id)] ?? .null
    //                     else { return nil }
    //                     return values.count
    //                 }.min() ?? 0
                    
    //                 ForEach(0..<minLength, id: \.self) { rowIndex in
    //                     HStack(spacing: 65) {
    //                         ForEach(groupedColumns, id: \.id) { column in
    //                             if case .array(let values) = item.columnValues[String(column.id)] ?? .null {
    //                                 Text("\(values[rowIndex])")
    //                                     .font(.system(size: 28, weight: .medium, design: .rounded))
    //                                     .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
    //                                     .frame(maxWidth: .infinity)
    //                                     .multilineTextAlignment(.center)
    //                             } else {
    //                                 Text("-")
    //                                     .font(.system(size: 28, weight: .medium, design: .rounded))
    //                                     .frame(maxWidth: .infinity)
    //                             }
    //                         }
    //                     }
    //                 }
    //             }
    //         }
            
    //         // MARK: - Single columns
    //         ForEach(0..<(singleColumns.count + 1) / 2, id: \.self) { rowIndex in
    //             HStack(spacing: 20) {
    //                 ForEach(0..<2) { columnIndex in
    //                     let index = rowIndex * 2 + columnIndex
    //                     if index < singleColumns.count {
    //                         let column = singleColumns[index]
    //                         if let value = item.columnValues[String(column.id)] {
    //                             VStack(alignment: .leading, spacing: 4) {
    //                                 Text(column.name)
    //                                     .font(.system(size: 18))
    //                                     .foregroundColor(.primary)
                                    
    //                                 Text(valueString(for: value))
    //                                     .font(.system(size: 28, weight: .medium, design: .rounded))
    //                                     .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
    //                             }
    //                             .frame(maxWidth: .infinity, alignment: .leading)
    //                         }
    //                     }
    //                 }
    //             }
    //         }
    //     }
    // }

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
