//
//  FullSummaryView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/6/25.
//

import SwiftUI

struct FullSummaryView: View {
    let items: [PodItem]
    let columns: [PodColumn]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color("bg")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(items.filter { item in
                        guard let columnValues = item.columnValues else { return false }
                        return !columnValues.isEmpty && columnValues.values.contains { value in
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
                    }) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(item.metadata)
                                .font(.system(size: 18))
                                .fontWeight(.semibold)
                                .lineLimit(2)
                                .fontDesign(.rounded)
                                .foregroundColor(.accentColor)
                            
                            columnValuesGrid(for: item)
                            
                            Divider()
                                .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 10)
            }
            .navigationTitle("Activity Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func columnValuesGrid(for item: PodItem) -> some View {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singleColumns = columns.filter { $0.groupingType == "singular" }
        
        return VStack(alignment: .leading, spacing: 24) {
            // Grouped columns section
            if !groupedColumns.isEmpty {
                VStack(spacing: 0) {
                    // Headers with fixed width alignment
                    HStack(spacing: 65) {
                        ForEach(groupedColumns, id: \.id) { column in
                            Text(column.name)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    
                    // Find minimum length of all value arrays
                    let minLength: Int = groupedColumns.compactMap { column in
                        guard case .array(let values) = item.columnValues?[String(column.id)] ?? .null else {
                            return nil
                        }
                        return values.count
                    }.min() ?? 0
                    
                    // Grouped values
                    ForEach(0..<minLength, id: \.self) { index in
                        HStack(spacing: 65) {
                            ForEach(groupedColumns, id: \.id) { column in
                                if case .array(let values) = item.columnValues?[String(column.id)] ?? .null {
                                    Text("\(values[index])")
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
            
            // Single columns section
            ForEach(0..<(singleColumns.count + 1) / 2, id: \.self) { rowIndex in
                HStack(spacing: 20) {
                    ForEach(0..<2) { columnIndex in
                        let index = rowIndex * 2 + columnIndex
                        if index < singleColumns.count {
                            let column = singleColumns[index]
                            if let value = item.columnValues?[String(column.id)] {
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

    // Helper function to convert ColumnValue to String
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
            return array.map { value in
                if case let .number(num) = value, floor(num) == num {
                    return String(format: "%.0f", num)
                }
                return "\(value)"
            }.joined(separator: ", ")
        case .null:
            return ""
        }
    }
}
