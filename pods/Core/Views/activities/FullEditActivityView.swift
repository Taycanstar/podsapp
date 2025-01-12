//
//  FullEditActivityView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/12/25.
//

import SwiftUI

struct FullEditActivityView: View {
    @Environment(\.dismiss) private var dismiss
    let activity: Activity
    let columns: [PodColumn]
    let onSave: (Activity) -> Void

    @State private var items: [ActivityItem]
    @State private var notes: String
    @State private var columnValues: [Int: [String: ColumnValue]] = [:]
    @State private var groupedRowsCounts: [Int: [String: Int]] = [:]
    @State private var expandedColumn: String?
    @FocusState private var focusedField: String?
    @State private var isSubmitting = false
    
    // If you want the same “showNotesInput” toggle as ActivityView
    @State private var showNotesInput = false  // optionally track if we show notes area

    init(activity: Activity, columns: [PodColumn], onSave: @escaping (Activity) -> Void) {
        self.activity = activity
        self.columns = columns
        self.onSave = onSave
        _items = State(initialValue: activity.items)
        
        // If notes were originally set, we can show them by default
        let initialNotes = activity.notes ?? ""
        _notes = State(initialValue: initialNotes)
        _showNotesInput = State(initialValue: !initialNotes.isEmpty)

        // Initialize columnValues & groupedRowsCounts
        var initialColumnValues: [Int: [String: ColumnValue]] = [:]
        var initialGroupedRowsCounts: [Int: [String: Int]] = [:]
        for item in activity.items {
            initialColumnValues[item.id] = item.columnValues
            var rowCounts: [String: Int] = [:]
            for column in columns where column.groupingType == "grouped" {
                if let values = item.columnValues[String(column.id)],
                   case .array(let array) = values {
                    rowCounts[String(column.id)] = array.count
                } else {
                    rowCounts[String(column.id)] = 0
                }
            }
            initialGroupedRowsCounts[item.id] = rowCounts
        }
        _columnValues = State(initialValue: initialColumnValues)
        _groupedRowsCounts = State(initialValue: initialGroupedRowsCounts)
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Same background color as ActivityView
                Color("iosbg")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: - ForEach of Items (like ActivityView)
                        ForEach(items) { item in
                            // One item block, styled similarly to ActivityView
                            VStack(alignment: .leading, spacing: 15) {
                                // Title (metadata)
                                Text(item.itemLabel)
                                    .font(.system(size: 18))
                                    .fontDesign(.rounded)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                                
                                // Column groups
                                let columnGroups = groupColumns(columns)
                                ForEach(Array(columnGroups.indices), id: \.self) { groupIndex in
                                    let columnGroup = columnGroups[groupIndex]
                                    
                                    if columnGroup.first?.groupingType == "singular" {
                                        ForEach(columnGroup, id: \.id) { column in
                                            VStack(alignment: .leading, spacing: 5) {
                                                SingularColumnActivityView(
                                                    itemId: item.id,
                                                    column: column,
                                                    columnValues: bindingForItem(item.id),
                                                    focusedField: $focusedField,
                                                    expandedColumn: $expandedColumn,
                                                    onValueChanged: { }
                                                )
                                            }
                                        }
                                    } else {
                                        GroupedColumnActivityView(
                                            itemId: item.id,
                                            columnGroup: columnGroup,
                                            groupedRowsCount: groupedRowsCounts[item.id]?[columnGroup.first?.groupingType ?? ""] ?? 1,
                                            onAddRow: { addRow(for: columnGroup, itemId: item.id) },
                                            onDeleteRow: { idx in deleteRow(at: idx, in: columnGroup, itemId: item.id) },
                                            columnValues: bindingForItem(item.id),
                                            focusedField: $focusedField,
                                            expandedColumn: $expandedColumn,
                                            onValueChanged: { }
                                        )
                                    }
                                }
                            }
                            .padding() // same as ActivityView does for each item
                        }
                        
                        // MARK: - Notes Section
                        // If you want the same approach as ActivityView:
                        if !showNotesInput {
                            // “Add Notes” button if user hasn’t revealed notes
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
                            .opacity(showNotesInput ? 0 : 1)
                            .animation(.easeInOut, value: showNotesInput)
                        }
                        
                        if showNotesInput {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.system(size: 18))
                                    .fontDesign(.rounded)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                                
                                // If you want a text editor like ActivityView does for the “Add Notes” area:
                                TextField("", text: $notes, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color("iosnp"))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                            .transition(.opacity)
                        }
                    }
                    .padding(.top, 10) // some top padding if you like
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveActivity()
                        }
                        .disabled(isSubmitting)
                    }
                    
                    // If you want a keyboard toolbar like ActivityView:
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
                        .fontWeight(.medium)
                    }
                }
                .navigationTitle("Edit Activity")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - groupColumns
    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singularColumns = columns.filter { $0.groupingType == "singular" }
        return [groupedColumns, singularColumns].filter { !$0.isEmpty }
    }

    // MARK: - Binding
    private func bindingForItem(_ itemId: Int) -> Binding<[String: ColumnValue]> {
        Binding(
            get: { columnValues[itemId] ?? [:] },
            set: { columnValues[itemId] = $0 }
        )
    }

    // MARK: - addRow / deleteRow (unchanged)
    private func addRow(for columnGroup: [PodColumn], itemId: Int) {
        let groupType = columnGroup.first?.groupingType ?? ""
        let currentRowIndex = groupedRowsCounts[itemId]?[groupType] ?? 1

        for column in columnGroup {
            let key = String(column.id)
            let currentValue = columnValues[itemId]?[key] ?? .array([])
            var values: [ColumnValue] = []
            
            if case .array(let existingValues) = currentValue {
                values = existingValues
            }
            
            // If number, replicate the same logic as in ActivityView
            if column.type == "number" {
                if case .number(1.0) = values.first {
                    values.append(.number(Double(values.count + 1)))
                } else {
                    values.append(values.last ?? .null)
                }
            } else {
                values.append(values.last ?? .null)
            }
            
            columnValues[itemId]?[key] = .array(values)
        }
        
        groupedRowsCounts[itemId]?[groupType] = currentRowIndex + 1
    }

    private func deleteRow(at index: Int, in columnGroup: [PodColumn], itemId: Int) {
        for column in columnGroup {
            let key = String(column.id)
            if var arrayValue = columnValues[itemId]?[key],
               case .array(var arr) = arrayValue,
               index < arr.count {
                arr.remove(at: index)
                columnValues[itemId]?[key] = .array(arr)
            }
        }
        
        let groupType = columnGroup.first?.groupingType ?? ""
        if let currentCount = groupedRowsCounts[itemId]?[groupType],
           currentCount > 0 {
            groupedRowsCounts[itemId]?[groupType] = currentCount - 1
        }
    }

    // MARK: - Save
    private func saveActivity() {
//        isSubmitting = true
//        // Rebuild items with updated columnValues
//        let updatedItems: [ActivityItem] = items.map { originalItem in
//            var newItem = originalItem
//            newItem.columnValues = columnValues[originalItem.id] ?? [:]
//            return newItem
//        }
//        let updatedActivity = Activity(
//            id: activity.id,
//            podId: activity.podId,
//            userEmail: activity.userEmail,
//            userName: activity.userName,
//            duration: activity.duration,
//            loggedAt: activity.loggedAt,
//            notes: notes.isEmpty ? nil : notes,
//            isSingleItem: activity.isSingleItem,
//            items: updatedItems
//        )
//        
//        onSave(updatedActivity)
//        dismiss()
    }

    // MARK: - Clear Field & Hide Keyboard
    private func clearFocusedField() {
        guard let fieldID = focusedField else { return }
        let parts = fieldID.split(separator: "_").map(String.init)
        guard parts.count >= 2 else { return }
        
        let itemId = Int(parts[0]) ?? 0
        let columnId = parts[1]
        
        // If we have rowIndex
        if parts.count == 3, let rowIndex = Int(parts[2]) {
            if var val = columnValues[itemId]?[columnId],
               case .array(var arr) = val, rowIndex < arr.count {
                arr[rowIndex] = .null
                columnValues[itemId]?[columnId] = .array(arr)
            }
        } else {
            // singular
            columnValues[itemId]?[columnId] = .null
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
