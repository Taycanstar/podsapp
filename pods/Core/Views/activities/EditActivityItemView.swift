//
//  EditActivityItemView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/18/25.
//

import SwiftUI

struct EditActivityItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var activityManager: ActivityManager
    let item: ActivityItem
    let columns: [PodColumn]
    
    // Parent activity that contains this item
    let parentActivity: Activity
    
    @State private var columnValues: [String: ColumnValue]
    @State private var notes: String
    @State private var showNotesInput: Bool
    @State private var isSubmitting = false
    @State private var expandedColumn: String?
    @FocusState private var focusedField: String?
    @State private var groupedRowsCounts: [String: Int] = [:]
    
    init(item: ActivityItem, parentActivity: Activity, columns: [PodColumn]) {
        self.item = item
        self.columns = columns
        self.parentActivity = parentActivity
        
        // Initialize state
        _columnValues = State(initialValue: item.columnValues)
        _notes = State(initialValue: parentActivity.notes ?? "")
        _showNotesInput = State(initialValue: (parentActivity.notes ?? "").isEmpty == false)
        
        // Initialize grouped rows counts
        var initialRowCounts: [String: Int] = [:]
        for column in columns where column.groupingType == "grouped" {
            if let values = item.columnValues[String(column.id)],
               case .array(let array) = values {
                initialRowCounts[column.groupingType ?? ""] = array.count
            } else {
                initialRowCounts[column.groupingType ?? ""] = 0
            }
        }
        _groupedRowsCounts = State(initialValue: initialRowCounts)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        Text(item.itemLabel)
                            .font(.system(size: 18))
                            .fontDesign(.rounded)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        // Column groups
                        let columnGroups = groupColumns(columns)
                        ForEach(Array(columnGroups.indices), id: \.self) { groupIndex in
                            let columnGroup = columnGroups[groupIndex]
                            
                            if columnGroup.first?.groupingType == "singular" {
                                ForEach(columnGroup, id: \.id) { column in
                                    SingularColumnView(
                                        column: column,
                                        columnValues: $columnValues,
                                        focusedField: _focusedField,
                                        expandedColumn: $expandedColumn,
                                        onValueChanged: { }
                                    )
                                }
                            } else {
                                GroupedColumnView(
                                    columnGroup: columnGroup,
                                    groupedRowsCount: groupedRowsCounts[columnGroup.first?.groupingType ?? ""] ?? 1,
                                    onAddRow: {
                                        addRow(for: columnGroup)
                                    },
                                    onDeleteRow: { idx in
                                        deleteRow(at: idx, in: columnGroup)
                                    },
                                    columnValues: $columnValues,
                                    focusedField: _focusedField,
                                    expandedColumn: $expandedColumn,
                                    onValueChanged: { }
                                )
                            }
                        }
                        
                        // Notes Section
                        if parentActivity.isSingleItem {
                            if !showNotesInput {
                                Button(action: {
                                    withAnimation {
                                        showNotesInput = true
                                    }
                                }) {
                                    Text("Add Notes")
                                        .font(.system(size: 16))
                                        .fontWeight(.medium)
                                        .foregroundColor(.accentColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                            
                            if showNotesInput {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Notes")
                                        .font(.system(size: 18))
                                        .fontDesign(.rounded)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.accentColor)
                                    
                                    TextField("", text: $notes, axis: .vertical)
                                        .textFieldStyle(.plain)
                                        .padding()
                                        .background(Color("iosnp"))
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(isSubmitting)
                    }
                    
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("Clear") {
                            clearFocusedField()
                        }
                        .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Button("Done") {
                            hideKeyboard()
                        }
                        .foregroundColor(.accentColor)
                    }
                }
                .navigationTitle("Edit Item")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    private func saveChanges() {
        isSubmitting = true
        
        // Convert column values to the format expected by the backend
        let convertedValues = columnValues.mapValues { value -> Any in
            convertColumnValueToAny(value)
        }
        
        // Create an array of items to update
        var itemsToUpdate = [(id: Int, notes: String?, columnValues: [String: Any])]()
        
        if parentActivity.isSingleItem {
            // For single item activities, update item and notes
            itemsToUpdate = [(
                id: item.itemId,
                notes: item.notes,
                columnValues: convertedValues
            )]
        } else {
            // For multi-item activities, update just this item's values
            // and preserve other items' values
            itemsToUpdate = parentActivity.items.map { activityItem in
                if activityItem.id == item.id {
                    return (
                        id: activityItem.itemId,
                        notes: activityItem.notes,
                        columnValues: convertedValues
                    )
                } else {
                    return (
                        id: activityItem.itemId,
                        notes: activityItem.notes,
                        columnValues: activityItem.columnValues.mapValues { convertColumnValueToAny($0) }
                    )
                }
            }
        }
        
        // Create local updated activity for optimistic update
        var updatedActivity = parentActivity
        if parentActivity.isSingleItem {
            updatedActivity.notes = notes
        }
        
        // Update the specific item's column values
        updatedActivity.items = updatedActivity.items.map { activityItem in
            var updatedItem = activityItem
            if activityItem.id == item.id {
                updatedItem.columnValues = columnValues
            }
            return updatedItem
        }
        
        // Optimistically update the UI
        if let idx = activityManager.activities.firstIndex(where: { $0.id == parentActivity.id }) {
            activityManager.activities[idx] = updatedActivity
        }
        
        // Dismiss immediately for responsive UI
        dismiss()
        
        // Make the network request
        activityManager.updateActivity(
            activityId: parentActivity.id,
            notes: parentActivity.isSingleItem ? (notes.isEmpty ? nil : notes) : parentActivity.notes,
            items: itemsToUpdate
        ) { result in
            DispatchQueue.main.async {
                self.isSubmitting = false
                switch result {
                case .success:
                    print("Successfully updated item")
                case .failure(let error):
                    print("Failed to update item:", error)
                }
            }
        }
    }
    
    // Helper functions from FullEditActivityView
    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singularColumns = columns.filter { $0.groupingType == "singular" }
        return [groupedColumns, singularColumns].filter { !$0.isEmpty }
    }
    
    private func convertColumnValueToAny(_ value: ColumnValue) -> Any {
        switch value {
        case .string(let str): return str
        case .number(let num): return num
        case .time(let timeValue): return timeValue
        case .array(let arr): return arr.map { convertColumnValueToAny($0) }
        case .null: return NSNull()
        }
    }
    
    // Row management functions
    private func addRow(for columnGroup: [PodColumn]) {
        let groupType = columnGroup.first?.groupingType ?? ""
        let currentRowIndex = groupedRowsCounts[groupType] ?? 1
        
        for column in columnGroup {
            let key = String(column.id)
            if case .array(let existingValues) = columnValues[key] {
                var values = existingValues
                
                // Determine the new value
                let newValue: ColumnValue
                if column.type == "number",
                   case .number(1.0) = values.first {
                    newValue = .number(Double(values.count + 1))
                } else {
                    newValue = values.last ?? .null
                }
                
                values.append(newValue)
                columnValues[key] = .array(values)
            } else {
                columnValues[key] = .array([.null])
            }
        }
        
        groupedRowsCounts[groupType] = currentRowIndex + 1
    }
    
    private func deleteRow(at index: Int, in columnGroup: [PodColumn]) {
        for column in columnGroup {
            let key = String(column.id)
            if case .array(var values) = columnValues[key] {
                if index < values.count {
                    values.remove(at: index)
                    columnValues[key] = .array(values)
                }
            }
        }
        
        let groupType = columnGroup.first?.groupingType ?? ""
        if let currentCount = groupedRowsCounts[groupType], currentCount > 0 {
            groupedRowsCounts[groupType] = currentCount - 1
        }
    }
    
    private func clearFocusedField() {
        if let focusedField = focusedField {
            let components = focusedField.split(separator: "_").map(String.init)
            if components.count == 2,
               let rowIndexInt = Int(components[1]) {
                let columnName = String(components[0])
                if var columnValue = columnValues[columnName],
                   case .array(var values) = columnValue {
                    if rowIndexInt < values.count {
                        values[rowIndexInt] = .null
                        columnValues[columnName] = .array(values)
                    }
                }
            } else {
                columnValues[focusedField] = .null
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                      to: nil, from: nil, for: nil)
    }
}
