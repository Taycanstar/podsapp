//
//import SwiftUI
//
//struct FullEditActivityView: View {
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var activityManager: ActivityManager
//    let activity: Activity
//    let columns: [PodColumn]
//
//    @State private var items: [ActivityItem]
//    @State private var notes: String
//    @State private var columnValues: [Int: [String: ColumnValue]] = [:]
//    @State private var groupedRowsCounts: [Int: [String: Int]] = [:]
//    @State private var expandedColumn: String?
//    @FocusState private var focusedField: String?
//    @State private var isSubmitting = false
//    @State private var showNotesInput = false
//
////    init(activity: Activity, columns: [PodColumn]) {
////        self.activity = activity
////        self.columns = columns
////        _items = State(initialValue: activity.items)
////        
////        let initialNotes = activity.notes ?? ""
////        _notes = State(initialValue: initialNotes)
////        _showNotesInput = State(initialValue: !initialNotes.isEmpty)
////
////        // Initialize columnValues & groupedRowsCounts
////        var initialColumnValues: [Int: [String: ColumnValue]] = [:]
////        var initialGroupedRowsCounts: [Int: [String: Int]] = [:]
////        for item in activity.items {
////            initialColumnValues[item.id] = item.columnValues
////            var rowCounts: [String: Int] = [:]
////            for column in columns where column.groupingType == "grouped" {
////                if let values = item.columnValues[String(column.id)],
////                   case .array(let array) = values {
////                    rowCounts[String(column.id)] = array.count
////                } else {
////                    rowCounts[String(column.id)] = 0
////                }
////            }
////            initialGroupedRowsCounts[item.id] = rowCounts
////        }
////        _columnValues = State(initialValue: initialColumnValues)
////        _groupedRowsCounts = State(initialValue: initialGroupedRowsCounts)
////    }
//    init(activity: Activity, columns: [PodColumn]) {
//        self.activity = activity
//        self.columns = columns
//        _items = State(initialValue: activity.items)
//        
//        let initialNotes = activity.notes ?? ""
//        _notes = State(initialValue: initialNotes)
//        _showNotesInput = State(initialValue: !initialNotes.isEmpty)
//        
//        var initialColumnValues: [Int: [String: ColumnValue]] = [:]
//        var initialGroupedRowsCounts: [Int: [String: Int]] = [:]
//        
//        for item in activity.items {
//            initialColumnValues[item.itemId] = item.columnValues  // Use itemId instead of id
//            var rowCounts: [String: Int] = [:]
//            
//            for column in columns where column.groupingType == "grouped" {
//                if let values = item.columnValues[String(column.id)],
//                   case .array(let array) = values {
//                    rowCounts[String(column.id)] = array.count
//                } else {
//                    rowCounts[String(column.id)] = 0
//                }
//            }
//            
//            initialGroupedRowsCounts[item.itemId] = rowCounts  // Use itemId here too
//        }
//        
//        _columnValues = State(initialValue: initialColumnValues)
//        _groupedRowsCounts = State(initialValue: initialGroupedRowsCounts)
//    }
//
//    var body: some View {
//        NavigationView {
//            ZStack {
//                Color("iosbg")
//                    .ignoresSafeArea()
//
//                ScrollView {
//                    VStack(spacing: 20) {
////                        ForEach(items) { item in
////                            VStack(alignment: .leading, spacing: 15) {
////                                Text(item.itemLabel)
////                                    .font(.system(size: 18))
////                                    .fontDesign(.rounded)
////                                    .fontWeight(.semibold)
////                                    .foregroundColor(.accentColor)
////                                
////                                let columnGroups = groupColumns(columns)
////                                ForEach(Array(columnGroups.indices), id: \.self) { groupIndex in
////                                    let columnGroup = columnGroups[groupIndex]
////                                    
////                                    if columnGroup.first?.groupingType == "singular" {
////                                        ForEach(columnGroup, id: \.id) { column in
////                                            VStack(alignment: .leading, spacing: 5) {
////                                                SingularColumnActivityView(
////                                                    itemId: item.id,
////                                                    column: column,
////                                                    columnValues: bindingForItem(item.id),
////                                                    focusedField: $focusedField,
////                                                    expandedColumn: $expandedColumn,
////                                                    onValueChanged: { }
////                                                )
////                                            }
////                                        }
////                                    } else {
////                                        GroupedColumnActivityView(
////                                            itemId: item.id,
////                                            columnGroup: columnGroup,
////                                            groupedRowsCount: groupedRowsCounts[item.id]?[columnGroup.first?.groupingType ?? ""] ?? 1,
////                                            onAddRow: { addRow(for: columnGroup, itemId: item.id) },
////                                            onDeleteRow: { idx in deleteRow(at: idx, in: columnGroup, itemId: item.id) },
////                                            columnValues: bindingForItem(item.id),
////                                            focusedField: $focusedField,
////                                            expandedColumn: $expandedColumn,
////                                            onValueChanged: { }
////                                        )
////                                    }
////                                }
////                            }
////                            .padding()
////                        }
//                        ForEach(items) { item in
//                            VStack(alignment: .leading, spacing: 15) {
//                                Text(item.itemLabel)
//                                    .font(.system(size: 18))
//                                    .fontDesign(.rounded)
//                                    .fontWeight(.semibold)
//                                    .foregroundColor(.accentColor)
//                                
//                                let columnGroups = groupColumns(columns)
//                                ForEach(Array(columnGroups.indices), id: \.self) { groupIndex in
//                                    let columnGroup = columnGroups[groupIndex]
//                                    
//                                    if columnGroup.first?.groupingType == "singular" {
//                                        ForEach(columnGroup, id: \.id) { column in
//                                            VStack(alignment: .leading, spacing: 5) {
//                                                SingularColumnActivityView(
//                                                    itemId: item.itemId,  // Change to itemId
//                                                    column: column,
//                                                    columnValues: bindingForItem(item.itemId),  // Change to itemId
//                                                    focusedField: $focusedField,
//                                                    expandedColumn: $expandedColumn,
//                                                    onValueChanged: { }
//                                                )
//                                            }
//                                        }
//                                    } else {
//                                        GroupedColumnActivityView(
//                                            itemId: item.itemId,  // Change to itemId
//                                            columnGroup: columnGroup,
//                                            groupedRowsCount: groupedRowsCounts[item.itemId]?[columnGroup.first?.groupingType ?? ""] ?? 1,  // Change to itemId
//                                            onAddRow: { addRow(for: columnGroup, itemId: item.itemId) },  // Change to itemId
//                                            onDeleteRow: { idx in deleteRow(at: idx, in: columnGroup, itemId: item.itemId) },  // Change to itemId
//                                            columnValues: bindingForItem(item.itemId),  // Change to itemId
//                                            focusedField: $focusedField,
//                                            expandedColumn: $expandedColumn,
//                                            onValueChanged: { }
//                                        )
//                                    }
//                                }
//                            }
//                            .padding()
//                        }
//                        
//                        if !showNotesInput {
//                            Button(action: {
//                                withAnimation {
//                                    showNotesInput = true
//                                }
//                            }) {
//                                Text("Add Notes")
//                                    .font(.system(size: 16))
//                                    .fontWeight(.medium)
//                                    .foregroundColor(.accentColor)
//                                    .frame(maxWidth: .infinity)
//                                    .padding(.vertical, 12)
//                                    .background(Color.accentColor.opacity(0.1))
//                                    .cornerRadius(8)
//                            }
//                            .padding(.horizontal)
//                            .opacity(showNotesInput ? 0 : 1)
//                            .animation(.easeInOut, value: showNotesInput)
//                        }
//                        
//                        if showNotesInput {
//                            VStack(alignment: .leading, spacing: 8) {
//                                Text("Notes")
//                                    .font(.system(size: 18))
//                                    .fontDesign(.rounded)
//                                    .fontWeight(.semibold)
//                                    .foregroundColor(.accentColor)
//                                
//                                TextField("", text: $notes, axis: .vertical)
//                                    .textFieldStyle(.plain)
//                                    .padding()
//                                    .background(Color("iosnp"))
//                                    .cornerRadius(12)
//                            }
//                            .padding(.horizontal)
//                            .padding(.bottom)
//                            .transition(.opacity)
//                        }
//                    }
//                    .padding(.top, 10)
//                }
//                .toolbar {
//                    ToolbarItem(placement: .navigationBarLeading) {
//                        Button("Cancel") {
//                            dismiss()
//                        }
//                    }
//                    ToolbarItem(placement: .navigationBarTrailing) {
//                        Button("Save") {
//                            saveActivity()
//                        }
//                        .disabled(isSubmitting)
//                    }
//                    
//                    ToolbarItemGroup(placement: .keyboard) {
//                        Button("Clear") {
//                            clearFocusedField()
//                        }
//                        .foregroundColor(.accentColor)
//
//                        Spacer()
//
//                        Button("Done") {
//                            hideKeyboard()
//                        }
//                        .foregroundColor(.accentColor)
//                        .fontWeight(.medium)
//                    }
//                }
//                .navigationTitle("Edit Activity")
//                .navigationBarTitleDisplayMode(.inline)
//            }
//        }
//    }
//
//    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
//        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
//        let singularColumns = columns.filter { $0.groupingType == "singular" }
//        return [groupedColumns, singularColumns].filter { !$0.isEmpty }
//    }
//
//    private func bindingForItem(_ itemId: Int) -> Binding<[String: ColumnValue]> {
//        Binding(
//            get: { columnValues[itemId] ?? [:] },
//            set: { columnValues[itemId] = $0 }
//        )
//    }
//
//    private func addRow(for columnGroup: [PodColumn], itemId: Int) {
//        let groupType = columnGroup.first?.groupingType ?? ""
//        let currentRowIndex = groupedRowsCounts[itemId]?[groupType] ?? 1
//
//        for column in columnGroup {
//            let key = String(column.id)
//            let currentValue = columnValues[itemId]?[key] ?? .array([])
//            var values: [ColumnValue] = []
//            
//            if case .array(let existingValues) = currentValue {
//                values = existingValues
//            }
//            
//            if column.type == "number" {
//                if case .number(1.0) = values.first {
//                    values.append(.number(Double(values.count + 1)))
//                } else {
//                    values.append(values.last ?? .null)
//                }
//            } else {
//                values.append(values.last ?? .null)
//            }
//            
//            columnValues[itemId]?[key] = .array(values)
//        }
//        
//        groupedRowsCounts[itemId]?[groupType] = currentRowIndex + 1
//    }
//
//    private func deleteRow(at index: Int, in columnGroup: [PodColumn], itemId: Int) {
//        for column in columnGroup {
//            let key = String(column.id)
//            if var arrayValue = columnValues[itemId]?[key],
//               case .array(var arr) = arrayValue,
//               index < arr.count {
//                arr.remove(at: index)
//                columnValues[itemId]?[key] = .array(arr)
//            }
//        }
//        
//        let groupType = columnGroup.first?.groupingType ?? ""
//        if let currentCount = groupedRowsCounts[itemId]?[groupType],
//           currentCount > 0 {
//            groupedRowsCounts[itemId]?[groupType] = currentCount - 1
//        }
//    }
//    
//    private func convertColumnValueToAny(_ value: ColumnValue) -> Any {
//        switch value {
//        case .number(let num):
//            return num
//        case .string(let str):
//            return str
//        case .time(let timeValue):
//            return timeValue.toString
//        case .array(let array):
//            return array.map { convertColumnValueToAny($0) }
//        case .null:
//            return NSNull()
//        }
//    }
//
//    private func saveActivity() {
//        let updatedItems: [(id: Int, notes: String?, columnValues: [String: Any])] = items.map { item in
//            let convertedValues = (columnValues[item.id] ?? [:]).mapValues { val in
//                convertColumnValueToAny(val)
//            }
//            return (
//                id: item.itemId,
//                notes: item.notes,
//                columnValues: convertedValues
//            )
//        }
//
//        var localUpdatedActivity = activity
//        localUpdatedActivity.notes = notes
//        
//        var newItems = [ActivityItem]()
//        for item in items {
//            var changedItem = item
//            changedItem.columnValues = columnValues[item.id] ?? [:]
//            newItems.append(changedItem)
//        }
//        localUpdatedActivity.items = newItems
//
//        if let idx = activityManager.activities.firstIndex(where: { $0.id == activity.id }) {
//            activityManager.activities[idx] = localUpdatedActivity
//        }
//
//        dismiss()
//
//        isSubmitting = true
//        activityManager.updateActivity(
//            activityId: activity.id,
//            notes: notes.isEmpty ? nil : notes,
//            items: updatedItems
//        ) { result in
//            DispatchQueue.main.async {
//                self.isSubmitting = false
//                switch result {
//                case .success:
//                    Task {
//                        await MainActor.run {
//                            activityManager.loadMoreActivities(refresh: true)
//                        }
//                    }
//                case .failure(let error):
//                    print("Failed to update activity in the backend:", error)
//                }
//            }
//        }
//    }
//
//    private func clearFocusedField() {
//        guard let fieldID = focusedField else { return }
//        let parts = fieldID.split(separator: "_").map(String.init)
//        guard parts.count >= 2 else { return }
//        
//        let itemId = Int(parts[0]) ?? 0
//        let columnId = parts[1]
//        
//        if parts.count == 3, let rowIndex = Int(parts[2]) {
//            if var val = columnValues[itemId]?[columnId],
//               case .array(var arr) = val, rowIndex < arr.count {
//                arr[rowIndex] = .null
//                columnValues[itemId]?[columnId] = .array(arr)
//            }
//        } else {
//            columnValues[itemId]?[columnId] = .null
//        }
//    }
//
//    private func hideKeyboard() {
//        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
//                                      to: nil, from: nil, for: nil)
//    }
//}

import SwiftUI

struct FullEditActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var activityManager: ActivityManager
    let activity: Activity
    let columns: [PodColumn]

    @State private var items: [ActivityItem]
    @State private var notes: String
    @State private var columnValues: [Int: [String: ColumnValue]] = [:]
    @State private var groupedRowsCounts: [Int: [String: Int]] = [:]
    @State private var expandedColumn: String?
    @FocusState private var focusedField: String?
    @State private var isSubmitting = false
    @State private var showNotesInput = false

    init(activity: Activity, columns: [PodColumn]) {
        self.activity = activity
        self.columns = columns
        _items = State(initialValue: activity.items)
        
        let initialNotes = activity.notes ?? ""
        _notes = State(initialValue: initialNotes)
        _showNotesInput = State(initialValue: !initialNotes.isEmpty)
        
        var initialColumnValues: [Int: [String: ColumnValue]] = [:]
        var initialGroupedRowsCounts: [Int: [String: Int]] = [:]
        
        // Initialize column values and row counts
        for item in activity.items {
            // Set column values
            initialColumnValues[item.itemId] = item.columnValues
            
            // Get max row count for grouped columns
            var maxCount = 0
            for column in columns where column.groupingType == "grouped" {
                if let values = item.columnValues[String(column.id)],
                   case .array(let array) = values {
                    maxCount = max(maxCount, array.count)
                }
            }
            
            // Set the row count for this item's grouped columns
            initialGroupedRowsCounts[item.itemId] = ["grouped": maxCount]
        }
        
        _columnValues = State(initialValue: initialColumnValues)
        _groupedRowsCounts = State(initialValue: initialGroupedRowsCounts)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color("iosbg")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 15) {
                                Text(item.itemLabel)
                                    .font(.system(size: 18))
                                    .fontDesign(.rounded)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                                
                                let columnGroups = groupColumns(columns)
                                ForEach(Array(columnGroups.indices), id: \.self) { groupIndex in
                                    let columnGroup = columnGroups[groupIndex]
                                    
                                    if columnGroup.first?.groupingType == "singular" {
                                        ForEach(columnGroup, id: \.id) { column in
                                            VStack(alignment: .leading, spacing: 5) {
                                                SingularColumnActivityView(
                                                    itemId: item.itemId,
                                                    column: column,
                                                    columnValues: bindingForItem(item.itemId),
                                                    focusedField: $focusedField,
                                                    expandedColumn: $expandedColumn,
                                                    onValueChanged: { }
                                                )
                                            }
                                        }
                                    } else {
                                        GroupedColumnActivityView(
                                            itemId: item.itemId,
                                            columnGroup: columnGroup,
                                            groupedRowsCount: groupedRowsCounts[item.itemId]?["grouped"] ?? 0,
                                            onAddRow: { addRow(for: columnGroup, itemId: item.itemId) },
                                            onDeleteRow: { idx in deleteRow(at: idx, in: columnGroup, itemId: item.itemId) },
                                            columnValues: bindingForItem(item.itemId),
                                            focusedField: $focusedField,
                                            expandedColumn: $expandedColumn,
                                            onValueChanged: { }
                                        )
                                    }
                                }
                            }
                            .padding()
                        }
                        
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
                    .padding(.top, 10)
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

    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singularColumns = columns.filter { $0.groupingType == "singular" }
        return [groupedColumns, singularColumns].filter { !$0.isEmpty }
    }

    private func bindingForItem(_ itemId: Int) -> Binding<[String: ColumnValue]> {
        Binding(
            get: { columnValues[itemId] ?? [:] },
            set: { columnValues[itemId] = $0 }
        )
    }

    private func addRow(for columnGroup: [PodColumn], itemId: Int) {
        // Add a new row to all columns in the group
        for column in columnGroup {
            let key = String(column.id)
            let currentValue = columnValues[itemId]?[key] ?? .array([])
            var values: [ColumnValue] = []
            
            if case .array(let existingValues) = currentValue {
                values = existingValues
            }
            
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
        
        // Update the row count
        if let currentCount = groupedRowsCounts[itemId]?["grouped"] {
            groupedRowsCounts[itemId]?["grouped"] = currentCount + 1
        } else {
            groupedRowsCounts[itemId] = ["grouped": 1]
        }
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
        
        // Update the row count
        if let currentCount = groupedRowsCounts[itemId]?["grouped"], currentCount > 0 {
            groupedRowsCounts[itemId]?["grouped"] = currentCount - 1
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
            return array.map { convertColumnValueToAny($0) }
        case .null:
            return NSNull()
        }
    }

    private func saveActivity() {
        let updatedItems: [(id: Int, notes: String?, columnValues: [String: Any])] = items.map { item in
            let convertedValues = (columnValues[item.itemId] ?? [:]).mapValues { val in
                convertColumnValueToAny(val)
            }
            return (
                id: item.itemId,
                notes: item.notes,
                columnValues: convertedValues
            )
        }

        var localUpdatedActivity = activity
        localUpdatedActivity.notes = notes
        
        var newItems = [ActivityItem]()
        for item in items {
            var changedItem = item
            changedItem.columnValues = columnValues[item.itemId] ?? [:]
            newItems.append(changedItem)
        }
        localUpdatedActivity.items = newItems

        if let idx = activityManager.activities.firstIndex(where: { $0.id == activity.id }) {
            activityManager.activities[idx] = localUpdatedActivity
        }

        dismiss()

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
                    Task {
                        await MainActor.run {
                            activityManager.loadMoreActivities(refresh: true)
                        }
                    }
                case .failure(let error):
                    print("Failed to update activity in the backend:", error)
                }
            }
        }
    }

    private func clearFocusedField() {
        guard let fieldID = focusedField else { return }
        let parts = fieldID.split(separator: "_").map(String.init)
        guard parts.count >= 2 else { return }
        
        let itemId = Int(parts[0]) ?? 0
        let columnId = parts[1]
        
        if parts.count == 3, let rowIndex = Int(parts[2]) {
            if var val = columnValues[itemId]?[columnId],
               case .array(var arr) = val, rowIndex < arr.count {
                arr[rowIndex] = .null
                columnValues[itemId]?[columnId] = .array(arr)
            }
        } else {
            columnValues[itemId]?[columnId] = .null
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                      to: nil, from: nil, for: nil)
    }
}
