////
////  FullActivitySummaryView.swift
////  Pods
////
////  Created by Dimi Nunez on 1/12/25.
import SwiftUI

struct FullActivitySummaryView: View {
    let activity: Activity
    let columns: [PodColumn]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Entire screen background
            Color("iosbg")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 10) {

                    // MARK: - List of Items
                    ForEach(activity.items.filter({ !shouldHideItem($0) }), id: \.id) { item in
                        
                        // 1) The item’s title *outside* the card
                        Text(item.itemLabel)
                            .font(.system(size: 18))
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .fontDesign(.rounded)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top)
                        
                        // 2) The “card” is just the column values
                        VStack(alignment: .leading, spacing: 10) {
                            columnValuesGrid(for: item)
                        }
                        .padding()
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        
                        // No bottom divider here
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
        }
    }
}

// MARK: - Column Values Grid
extension FullActivitySummaryView {
    /// Decide if an item should be hidden based on column values
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
        let singleColumns  = columns.filter { $0.groupingType == "singular" }

        return VStack(alignment: .leading, spacing: 24) {
            // MARK: - Grouped columns
            if !groupedColumns.isEmpty {
                VStack(spacing: 0) {
                    // Headers
                    HStack(spacing: 65) {
                        ForEach(groupedColumns, id: \.id) { column in
                            Text(column.name)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    
                    // Data rows
                    let minLength: Int = groupedColumns.compactMap { column in
                        guard case .array(let values) = item.columnValues[String(column.id)] ?? .null
                        else { return nil }
                        return values.count
                    }.min() ?? 0
                    
                    ForEach(0..<minLength, id: \.self) { rowIndex in
                        HStack(spacing: 65) {
                            ForEach(groupedColumns, id: \.id) { column in
                                if case .array(let values) = item.columnValues[String(column.id)] ?? .null {
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
                            if let value = item.columnValues[String(column.id)] {
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

//import SwiftUI
//
//struct FullActivitySummaryView: View {
//    // Incoming data
//    let activity: Activity
//    let columns: [PodColumn]
//    
//    @Environment(\.dismiss) private var dismiss
//    
//    var body: some View {
//        ZStack {
//            Color("bg")
//                .ignoresSafeArea()
//            
//            ScrollView {
//                VStack(spacing: 24) {
//                    
//                    // MARK: - ForEach of ActivityItems
//                    ForEach(
//                        activity.items.filter { item in
//                            // Optional filter logic:
//                            // 1) Make sure columnValues is not nil or empty
//                            guard !item.columnValues.isEmpty else { return false }
//                            // 2) Check if any value is non-empty
//                            return item.columnValues.values.contains { value in
//                                switch value {
//                                case .null:
//                                    return false
//                                case .string(let str):
//                                    return !str.isEmpty
//                                case .number:
//                                    return true
//                                case .time(let timeValue):
//                                    // If you don't use TimeValue, remove this check
//                                    return timeValue != TimeValue(hours: 0, minutes: 0, seconds: 0)
//                                case .array(let values):
//                                    return values.contains { val in
//                                        if case .null = val { return false }
//                                        return true
//                                    }
//                                }
//                            }
//                        },
//                        id: \.id  // <-- critical so SwiftUI doesn't try the Binding initializer
//                    ) { item in
//                        
//                        VStack(alignment: .leading, spacing: 10) {
//                            // Show the item label
//                            Text(item.itemLabel)
//                                .font(.system(size: 18))
//                                .fontWeight(.semibold)
//                                .lineLimit(2)
//                                .fontDesign(.rounded)
//                                .foregroundColor(.accentColor)
//                            
//                            // Show columns data
//                            columnValuesGrid(for: item)
//                            
//                            Divider()
//                                .padding(.vertical, 10)
//                        }
//                        .padding(.horizontal, 20)
//                    }
//                    
//                    if let notes = activity.notes, !notes.isEmpty {
//                                           VStack(alignment: .leading, spacing: 20) {
//                                               Text("Notes")
//                                                   .font(.system(size: 24, weight: .bold))
//                                               
//                                               Text(notes)
//                                                   .font(.system(size: 16))
//                                                   .padding()
//                                                   .frame(maxWidth: .infinity, alignment: .leading)
//                                                   .background(Color("iosnp"))
//                                                   .cornerRadius(12)
//                                               
////                                               Divider()
//                                           }
//                                           .padding(.horizontal, 20)
//                                            
//                     
//                                       }
//                }
//                .padding(.vertical, 10)
//            }
//            // MARK: - Nav Bar
//            .navigationTitle(formattedDate(activity.loggedAt))
//            .navigationBarTitleDisplayMode(.inline)
//        }
//    }
//}
//
//// MARK: - Column Values Grid
//extension FullActivitySummaryView {
//    private func columnValuesGrid(for item: ActivityItem) -> some View {
//        // Split columns into grouped vs single
//        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
//        let singleColumns = columns.filter { $0.groupingType == "singular" }
//        
//        return VStack(alignment: .leading, spacing: 24) {
//            
//            // MARK: - Grouped columns
//            if !groupedColumns.isEmpty {
//                VStack(spacing: 0) {
//                    // Column headers
//                    HStack(spacing: 65) {
//                        ForEach(groupedColumns, id: \.id) { column in
//                            Text(column.name)
//                                .font(.system(size: 18))
//                                .foregroundColor(.primary)
//                                .frame(maxWidth: .infinity, alignment: .center)
//                        }
//                    }
//                    
//                    // Find the smallest number of rows among grouped columns
//                    let minLength: Int = groupedColumns.compactMap { column in
//                        guard case .array(let values) = item.columnValues[String(column.id)] ?? .null
//                        else { return nil }
//                        return values.count
//                    }.min() ?? 0
//                    
//                    // Display each row
//                    ForEach(0..<minLength, id: \.self) { rowIndex in
//                        HStack(spacing: 65) {
//                            ForEach(groupedColumns, id: \.id) { column in
//                                if case .array(let values) = item.columnValues[String(column.id)] ?? .null {
//                                    Text("\(values[rowIndex])")
//                                        .font(.system(size: 28, weight: .medium, design: .rounded))
//                                        .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
//                                        .frame(maxWidth: .infinity)
//                                        .multilineTextAlignment(.center)
//                                } else {
//                                    Text("-")
//                                        .font(.system(size: 28, weight: .medium, design: .rounded))
//                                        .frame(maxWidth: .infinity)
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            
//            // MARK: - Single columns
//            ForEach(0..<(singleColumns.count + 1) / 2, id: \.self) { rowIndex in
//                HStack(spacing: 20) {
//                    ForEach(0..<2) { columnIndex in
//                        let index = rowIndex * 2 + columnIndex
//                        if index < singleColumns.count {
//                            let column = singleColumns[index]
//                            // Check for a value
//                            if let value = item.columnValues[String(column.id)] {
//                                VStack(alignment: .leading, spacing: 4) {
//                                    Text(column.name)
//                                        .font(.system(size: 18))
//                                        .foregroundColor(.primary)
//                                    
//                                    Text(valueString(for: value))
//                                        .font(.system(size: 28, weight: .medium, design: .rounded))
//                                        .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
//                                }
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    // Convert ColumnValue to a String
//    private func valueString(for value: ColumnValue) -> String {
//        switch value {
//        case .string(let str):
//            return str
//        case .number(let num):
//            // If it's an integer, show no decimal
//            if floor(num) == num {
//                return String(format: "%.0f", num)
//            } else {
//                return "\(num)"
//            }
//        case .time(let timeValue):
//            // Convert your TimeValue to a String
//            return timeValue.toString
//        case .array(let array):
//            // Convert each element to string
//            return array.map { element in
//                if case let .number(num) = element, floor(num) == num {
//                    return String(format: "%.0f", num)
//                }
//                // Fallback
//                return "\(element)"
//            }.joined(separator: ", ")
//        case .null:
//            return ""
//        }
//    }
//}
//
//// MARK: - Date Formatting
//extension FullActivitySummaryView {
//    private func formattedDate(_ date: Date) -> String {
//        let calendar = Calendar.current
//        let now = Date()
//        
//        if calendar.isDateInToday(date) {
//            return "Today, \(formatMonthDay(date)), \(formatYear(date))"
//        } else if calendar.isDateInYesterday(date) {
//            return "Yesterday, \(formatMonthDay(date)), \(formatYear(date))"
//        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
//            let weekdayFormatter = DateFormatter()
//            weekdayFormatter.dateFormat = "EEEE"
//            return "\(weekdayFormatter.string(from: date)), \(formatMonthDay(date)), \(formatYear(date))"
//        } else {
//            let weekdayFormatter = DateFormatter()
//            weekdayFormatter.dateFormat = "EEEE"
//            return "\(weekdayFormatter.string(from: date)), \(formatMonthDay(date)), \(formatYear(date))"
//        }
//    }
//    
//    private func formatMonthDay(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "MMM d"
//        return formatter.string(from: date)
//    }
//    
//    private func formatYear(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy"
//        return formatter.string(from: date)
//    }
//}

