//
//  FullActivityLogView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/28/24.
//

import SwiftUI

struct FullActivityLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let log: PodItemActivityLog
    let columns: [PodColumn]
    let onDelete: (PodItemActivityLog) -> Void

    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
    
    var body: some View {
        ZStack {
            (Color("bg"))
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 0) {
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(log.itemLabel)
                            .font(.system(size: 32))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.bottom, 10)
                        
                        columnValuesGrid
                        
                        Divider() // Add a divider here
                               .padding(.vertical, 10)
                        
                        if !log.notes.isEmpty {
                            
                            Text("Notes")
                                .font(.system(size: 24))
                                .fontWeight(.bold)
                                .padding(.top)
//                                .padding(.horizontal)

                            Text(log.notes)
                                .font(.body)
//                                .padding(.horizontal)
                            
                            Divider() // Add a divider here
                                   .padding(.bottom, 10)
                        }
                        Spacer(minLength: 10) // Add space before the delete button
                                                
                                             
                            
                            
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color("bg"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(formattedDate(log.loggedAt))
            .toolbar {
                  ToolbarItem(placement: .navigationBarTrailing) {
                      Menu {
                          Button {
                              // Edit logic here if needed
                              // For now, just print
                              print("Edit tapped")
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
                                           .frame(width: 25, height: 25) // Adjust size for breathing room
                                       Image(systemName: "ellipsis")
                                  .font(.system(size: 14))
                                           .foregroundColor(.accentColor)
                                   }
                      }
                  }
              }
          
          .alert("Delete Activity", isPresented: $showDeleteAlert) {
              Button("Cancel", role: .cancel) { }
              Button("Delete", role: .destructive) {
                  deleteLog()
              }
          } message: {
              Text("Are you sure you want to delete this activity?")
          }
        }
    }
    
    // Format just the time for the detail view
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Format the date for the navigation title
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today, \(formatMonthDay(date)), \(formatYear(date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(formatMonthDay(date)), \(formatYear(date))"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            // Within the same week
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
    
    private var deleteLogButton: some View {
        Button(action: {
            showDeleteAlert = true
        }) {
            Text("Delete log")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .disabled(isDeleting)
    }

    private func deleteLog() {
        isDeleting = true
        NetworkManager().deleteActivityLog(logId: log.id) { result in
            DispatchQueue.main.async {
                isDeleting = false
                switch result {
                case .success:
                    onDelete(log) // Pass the log as we now have a closure expecting a PodItemActivityLog
                    dismiss()
                case .failure(let error):
                    print("Failed to delete log: \(error.localizedDescription)")
                }
            }
        }
    }


    private var columnValuesGrid: some View {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singleColumns = columns.filter { $0.groupingType == "singular" }
        
        return VStack(alignment: .leading, spacing: 24) {
            // Grouped columns section
            if !groupedColumns.isEmpty {
                VStack(spacing: 0) {
                    // Headers
                    HStack {
                        ForEach(Array(groupedColumns.enumerated()), id: \.element.id) { index, column in
                            Text(column.name)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                            
                            if index < groupedColumns.count - 1 {
                                Spacer()
                            }
                        }
                    }
                    
                    // Find minimum length of all value arrays
                    let minLength: Int = groupedColumns.compactMap { column in
                        guard case .array(let values) = log.columnValues[column.name] ?? .null else {
                            return nil
                        }
                        return values.count
                    }.min() ?? 0
                    
                    // Values - only show up to minLength rows
                    ForEach(0..<minLength, id: \.self) { index in
                        HStack {
                            ForEach(Array(groupedColumns.enumerated()), id: \.element.id) { colIndex, column in
                                if case .array(let values) = log.columnValues[column.name] ?? .null {
                                    Text("\(values[index])")
                                        .font(.system(size: 28, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(red: 0.61, green: 0.62, blue: 0.68))
                                    
                                    if colIndex < groupedColumns.count - 1 {
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Single columns section remains the same...
            ForEach(0..<(singleColumns.count + 1) / 2, id: \.self) { rowIndex in
                HStack(spacing: 20) {
                    ForEach(0..<2) { columnIndex in
                        let index = rowIndex * 2 + columnIndex
                        if index < singleColumns.count {
                            let column = singleColumns[index]
                            if let value = log.columnValues[column.name] {
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
//        .padding(.horizontal)
    }

    private func columnView(key: String, value: ColumnValue) -> some View {
        VStack(alignment: .leading) {
            Text(key)
                .font(.system(size: 14))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(valueString(for: value))
                .font(.system(size: 16))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

//    private func valueString(for value: ColumnValue) -> String {
//        switch value {
//        case .string(let str):
//            return str
//        case .number(let num):
//            return "\(num)"
//        case .time(let timeValue):
//            return timeValue.toString
//        case .array(let array):
//            return array.map { $0.description }.joined(separator: ", ")
//        case .null:
//            return ""
//        }
//    }
    
    private func valueString(for value: ColumnValue) -> String {
        switch value {
        case .string(let str):
            return str
        case .number(let num):
            // Check if the number is effectively a whole number
            if floor(num) == num {
                return String(format: "%.0f", num)  // Format as integer
            } else {
                return "\(num)"  // Keep decimals for actual floating point numbers
            }
        case .time(let timeValue):
            return timeValue.toString
        case .array(let array):
            return array.map { value in
                if let num = value as? Double {
                    // Apply the same formatting to array numbers
                    if floor(num) == num {
                        return String(format: "%.0f", num)
                    }
                }
                return "\(value)"
            }.joined(separator: ", ")
        case .null:
            return ""
        }
    }


    

}
