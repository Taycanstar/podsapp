import SwiftUI

struct ItemSummaryView: View {
    let itemId: Int
    let columns: [PodColumn]
    @EnvironmentObject var activityManager: ActivityManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var showEditSheet = false
    
    private var parentActivity: Activity? {
        activityManager.activities.first { activity in
            activity.items.contains { $0.id == itemId }
        }
    }
    
    private var currentItem: ActivityItem? {
        parentActivity?.items.first { $0.id == itemId }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color("iosbg")
                .ignoresSafeArea()
            
            if let item = currentItem {
                ScrollView {
                    VStack(spacing: 10) {
                        // Item Title
                        Text(item.itemLabel)
                            .font(.system(size: 18))
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .fontDesign(.rounded)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top)
                        
                        // Column Values Card
                        VStack(alignment: .leading, spacing: 10) {
                            columnValuesGrid(item: item)
                        }
                        .padding()
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        
                        // Notes Section
                        if let notes = item.notes, !notes.isEmpty {
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
                .navigationTitle(formattedDate(item.loggedAt))
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
                                Label("Delete", systemImage: "trash")
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
                    if let activity = parentActivity {
                        EditActivityItemView(
                            item: item,
                            parentActivity: activity,
                            columns: columns
                        )
                    }
                }
            }
        }
        .alert("Delete Item", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteItem()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this item?")
        }
    }
    
    private func columnValuesGrid(item: ActivityItem) -> some View {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singleColumns = columns.filter { $0.groupingType == "singular" }
        
        // Create a mapping between column IDs and their values for easier lookup
        let columnValues = item.columnValues
        
        return VStack(alignment: .leading, spacing: 24) {
            // MARK: - Grouped columns
            if !groupedColumns.isEmpty {
                // Check if any grouped column has values in this item
                let hasGroupedValues = groupedColumns.contains { column in
                    let columnId = String(column.id)
                    if let value = columnValues[columnId], case .array(let arr) = value, !arr.isEmpty {
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
                                            Text(valueString(values[rowIndex]))
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
                                                Text(valueString(values[rowIndex]))
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
                                            
                                            Text(valueString(value))
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
                                            
                                            Text(valueString(value))
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
    
    private func valueString(_ value: ColumnValue) -> String {
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
            return "-"
        }
    }
    
    private func deleteItem() {
        if let activity = parentActivity {
            activityManager.deleteActivity(activity)
            dismiss()
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today, \(formatMonthDay(date)), \(formatYear(date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(formatMonthDay(date)), \(formatYear(date))"
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
