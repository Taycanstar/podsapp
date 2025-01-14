//
//  FullEditActivityView.swift
//  Pods
//
//  Created by Dimi Nunez on 1/12/25.
//

import SwiftUI

struct FullEditActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var activityManager: ActivityManager
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

    init(activityManager: ActivityManager, activity: Activity, columns: [PodColumn], onSave: @escaping (Activity) -> Void) {
        self._activityManager = ObservedObject(wrappedValue: activityManager)
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
//                .onAppear {
//                            initializeActivityManager()
//                        }
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
    
    private func convertColumnValueToAny(_ value: ColumnValue) -> Any {
        switch value {
        case .number(let num):
            return num
        case .string(let str):
            return str
        case .time(let timeValue):
            return timeValue.toString
        case .array(let array):
            // Recursively convert each element
            return array.map { convertColumnValueToAny($0) }
        case .null:
            return NSNull()
        }
    }
    

    // MARK: - Save
//    private func saveActivity() {
//        isSubmitting = true
//        
//        // 1) Rebuild items array
//        let updatedItems: [(id: Int, notes: String?, columnValues: [String: Any])] = items.map { item in
//            let convertedValues = (columnValues[item.id] ?? [:]).mapValues { val in
//                convertColumnValueToAny(val)
//            }
//            return (
//                id: item.itemId,     // must match the PodItem ID for the backend
//                notes: item.notes,
//                columnValues: convertedValues
//            )
//        }
//
//        // 2) Call the new manager function
//        activityManager.updateActivity(
//            activityId: activity.id,
//            notes: notes.isEmpty ? nil : notes,
//            items: updatedItems
//        ) { result in
//            DispatchQueue.main.async {
//                self.isSubmitting = false
//                switch result {
//                case .success:
//                    // 3) Retrieve the now-updated version from the manager (if needed)
//                    // or just pass back the updated version from the manager
//                    if let idx = self.activityManager.activities.firstIndex(where: { $0.id == self.activity.id }) {
//                        let updated = self.activityManager.activities[idx]
//                        self.onSave(updated)
//                    } else {
//                        // fallback, pass the old activity or handle error
//                        self.onSave(self.activity)
//                    }
//                    self.dismiss()
//
//                case .failure(let error):
//                    print("Failed to update activity:", error)
//                    // Show an alert or handle UI error state
//                }
//            }
//        }
//    }
    
    private func saveActivity() {
        // 1) Build the updatedItems array for the backend
        let updatedItems: [(id: Int, notes: String?, columnValues: [String: Any])] = items.map { item in
            let convertedValues = (columnValues[item.id] ?? [:]).mapValues { val in
                convertColumnValueToAny(val)
            }
            return (
                id: item.itemId,
                notes: item.notes,
                columnValues: convertedValues
            )
        }

        // 2) Construct a local updated Activity
        var localUpdatedActivity = activity
        localUpdatedActivity.notes = notes
        
        // Update each item’s columnValues
        var newItems = [ActivityItem]()
        for item in items {
            var changedItem = item
            changedItem.columnValues = columnValues[item.id] ?? [:]
            newItems.append(changedItem)
        }
        localUpdatedActivity.items = newItems

        // 3) **Optimistically update** the manager’s activities array
        if let idx = activityManager.activities.firstIndex(where: { $0.id == activity.id }) {
            activityManager.activities[idx] = localUpdatedActivity
        } else {
            // If this activity somehow wasn’t in the array, just add it
            activityManager.activities.append(localUpdatedActivity)
        }

        // 4) Optionally call onSave(...) if your parent also needs a callback
        //    (not strictly required if parent's only data source is activityManager.activities)
        onSave(localUpdatedActivity)

        // 5) Instantly dismiss the sheet => no lag for the user
        dismiss()

        // 6) Fire the actual update call in the background
        isSubmitting = true
        activityManager.updateActivity(
            activityId: activity.id,
            notes: notes.isEmpty ? nil : notes,
            items: updatedItems
        ) { result in
            DispatchQueue.main.async {
                self.isSubmitting = false
                switch result {
                case .success:
                    // If the server returns a more “definitive” updatedActivity,
                    // you can merge it in. For example:
                    //   if let new = updatedActivityFromServer,
                    //      let finalIdx = activityManager.activities.firstIndex(...)
                    //   activityManager.activities[finalIdx] = new
                    break
                case .failure(let error):
                    // Optional: revert or show an alert.
                    // The user already sees the updated data, so decide how you handle a failure.
                    print("Failed to update activity in the backend:", error)
                }
            }
        }
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
