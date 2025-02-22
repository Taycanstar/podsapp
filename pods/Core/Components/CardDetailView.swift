//
//  CardDetailView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/18/25.
//

import SwiftUI
import Foundation

struct CardDetailView: View {
    @Binding var item: PodItem
    @Binding var podColumns: [PodColumn]
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var itemName: String
    @State private var columnValues: [String: ColumnValue]
    let networkManager: NetworkManager
    @State private var showAddColumn = false
    @State private var showItemOptions = false
    @State private var showNotesInput = false
    @State private var addColumnOffset: CGFloat = UIScreen.main.bounds.height + 250
    @Binding var allItems: [PodItem]
    @State private var isAddingColumn = false
    @State private var newColumnName = ""
    @State private var newColumnType = ""
    let podId: Int
    @State private var itemOptionsOffset: CGFloat = UIScreen.main.bounds.height
    
    @FocusState private var isItemNameFocused: Bool
    
    @State private var showDeleteConfirmation = false
    @State private var expandedColumn: String?
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var itemNotes: String
    @State private var logNotes: String?
    @FocusState private var focusedField: String?

    @Binding var visibleColumns: [String]
    @State private var hasUnsavedChanges = false
    @EnvironmentObject var activityManager: ActivityManager
    let podTitle: String




    @State private var groupedRowsCount: [String: Int] = [:]
    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
            let groupedColumns = columns.filter { $0.groupingType == "grouped" }
            let singularColumns = columns.filter { $0.groupingType == "singular" }
            return [groupedColumns, singularColumns].filter { !$0.isEmpty }
        }
    



  init(item: Binding<PodItem>, podId: Int, podTitle: String, podColumns: Binding<[PodColumn]>, networkManager: NetworkManager, allItems: Binding<[PodItem]>, visibleColumns: Binding<[String]>) {
    self._item = item
    self.podTitle = podTitle
    self._itemName = State(initialValue: item.wrappedValue.metadata)
    self._podColumns = podColumns
    self.networkManager = networkManager
    self._allItems = allItems
    self.podId = podId
    self._itemNotes = State(initialValue: item.wrappedValue.notes ?? "")
    self._visibleColumns = visibleColumns

    // Initialize columnValues with proper empty arrays
    var initialColumnValues: [String: ColumnValue] = [:]
    var initialGroupedRowsCount: [String: Int] = [:]

    for column in podColumns.wrappedValue {
        let columnId = String(column.id)
        if let value = item.wrappedValue.columnValues?[columnId] {
            if column.groupingType == "grouped" {
                if case .array(let columnValues) = value {
                    initialColumnValues[columnId] = .array(columnValues.isEmpty ? [.null] : columnValues)
                    initialGroupedRowsCount[column.groupingType ?? ""] = max(1, columnValues.count)
                } else {
                    initialColumnValues[columnId] = .array([value])
                    initialGroupedRowsCount[column.groupingType ?? ""] = 1
                }
            } else {
                initialColumnValues[columnId] = value
            }
        } else {
            // Initialize empty columns
            if column.groupingType == "grouped" {
                initialColumnValues[columnId] = .array([.null])  // Start with one empty row
                initialGroupedRowsCount[column.groupingType ?? ""] = 1
            } else {
                initialColumnValues[columnId] = .null
            }
        }
    }

    self._columnValues = State(initialValue: initialColumnValues)
    self._groupedRowsCount = State(initialValue: initialGroupedRowsCount)
}

    
    var body: some View {
        ZStack {
            NavigationView {
                ZStack {
                    (Color("iosbg"))
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 0) {  // Main container
                                       ScrollView {
                                           VStack(alignment: .leading, spacing: 20) {
                                               TextField("Item Name", text: Binding(
                                                   get: { itemName },
                                                   set: {
                                                       itemName = $0
                                                       checkForChanges()
                                                   }
                                               ))
                                               .font(.system(size: 18)).bold()
                                               .background(Color.clear)
                                               .focused($isItemNameFocused)
                                               
                                               let columnGroups = groupColumns(podColumns)
                                               ForEach(Array(columnGroups.indices), id: \.self) { groupIndex in
                                                   let columnGroup = columnGroups[groupIndex]
                                                   
                                                   if columnGroup.first?.groupingType == "singular" {
                                                       ForEach(columnGroup, id: \.name) { column in
                                                           SingularColumnView(
                                                               column: column,
                                                               columnValues: $columnValues,
                                                               focusedField: _focusedField,
                                                               expandedColumn: $expandedColumn,
                                                               onValueChanged: checkForChanges
                                                           )
                                                       }
                                                   } else {
                                                       GroupedColumnView(
                                                           columnGroup: columnGroup,
                                                            groupedRowsCount: Binding(
                                                            get: { groupedRowsCount[columnGroup.first?.groupingType ?? ""] ?? 1 },
                                                            set: { groupedRowsCount[columnGroup.first?.groupingType ?? ""] = $0 }
                                                        ),
                                                           onAddRow: {
                                                               withAnimation {
                                                                   addRow(for: columnGroup)
                                                               }
                                                           },
                                                           onDeleteRow: { rowIndex in
                                                               withAnimation {
                                                                   deleteRow(at: rowIndex, in: columnGroup)
                                                               }
                                                           },
                                                           columnValues: $columnValues,
                                                           focusedField: _focusedField,
                                                           expandedColumn: $expandedColumn,
                                                           onValueChanged: checkForChanges
                                                       )
                                                   }
                                               }
                                               
                                               VStack(alignment: .leading) {
                                                   Text("Description")
                                                       .font(.system(size: 15))
                                                       .foregroundColor(.primary)
                                                       .padding(.horizontal, 5)
                                                       .kerning(0.2)

                                                   CustomTextEditor(text: Binding(
                                                       get: { itemNotes },
                                                       set: {
                                                           itemNotes = $0
                                                           checkForChanges()
                                                       }
                                                   ), backgroundColor: UIColor(Color("iosnp")))
                                                       .frame(height: 100)
                                                       .padding(.vertical, 8)
                                                       .padding(.horizontal)
                                                       .background(Color("iosnp"))
                                                       .cornerRadius(12)
                                               }
                                               
                                               if showNotesInput {
                                                   VStack(alignment: .leading) {
                                                       Text("Notes")
                                                           .font(.system(size: 15))
                                                           .foregroundColor(.primary)
                                                           .padding(.horizontal, 5)
                                                           .kerning(0.2)

                                                       CustomTextEditor(text: Binding(
                                                           get: { logNotes ?? "" },
                                                           set: {
                                                               logNotes = $0
                                                           }
                                                       ), backgroundColor: UIColor(Color("iosnp")))
                                                           .frame(height: 100)
                                                           .padding(.vertical, 8)
                                                           .padding(.horizontal)
                                                           .background(Color("iosnp"))
                                                           .cornerRadius(12)
                                                   }
                                               } else {
                                                   Button(action: {
                                                       withAnimation {
                                                           showNotesInput = true
                                                       }
                                                   }) {
                                                       Text("Add Notes")
                                                           .foregroundColor(.accentColor)
                                                   }
                                                   .frame(maxWidth: .infinity)
                                                   .padding(.top, 8)
                                               }
                                           }
                                           .padding()
                                       }
                                       
                                       // Log Single Item button fixed at bottom
                                       VStack {
                                           Button(action: {
                                               print("Log Activity tapped")
                                               logSingleItem()
                                           }) {
                                               Text("Log Single Item")
                                                   .font(.system(size: 16))
                                                   .fontWeight(.medium)
                                                   .foregroundColor(.accentColor)
                                                   .frame(maxWidth: .infinity)
                                                   .padding(.vertical, 12)
                                                   .background(Color.accentColor.opacity(0.1))
                                                   .cornerRadius(8)
                                           }
                                           .padding(.horizontal)
                                           .padding(.bottom, 16) // Add some bottom padding for better spacing
                                       }
                                       .background(Color("iosbg")) // Match the background color
                                   }
                                   
                                   .sheet(isPresented: $showAddColumn) {
                                       AddColumnView(isPresented: $showAddColumn, onAddColumn: addNewColumn)
                                           .presentationDetents([.height(UIScreen.main.bounds.height / 3.5)])
                                   }
                               }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("Clear") {
                            if let focusedField = focusedField {
                                  let components = focusedField.split(separator: "_").map(String.init)
                                  if components.count == 2,
                                     let rowIndexInt = Int(components[1]) {
                                      // For grouped columns
                                      let columnName = components[0]
                                      if var columnValue = columnValues[columnName], case .array(var values) = columnValue {
                                          if rowIndexInt < values.count {
                                              values[rowIndexInt] = .null
                                              columnValues[columnName] = .array(values)
                                          }
                                      }
                                  } else {
                                      // For singular columns - just clear the value directly
                                      columnValues[focusedField] = .null
                                  }
                              }
                          }
                        .foregroundColor(.accentColor)
                        
                        Spacer()
                        
                        Button("Done") {
                            focusedField = nil
                            isItemNameFocused = false
                        }
                        .foregroundColor(.accentColor)
                        .fontWeight(.medium)
                    }
                }
                .navigationBarItems(
                            leading: Button(action: {
                                // Simply dismiss without saving
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.primary)
                            },
                            trailing: HStack(spacing: 12) {
                                Button(action: {
                                    showItemOptions = true
                                }) {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundColor(.primary)
                                }
                                
                                // Only show Done button if there are unsaved changes
                                if hasUnsavedChanges {
                                    Button(action: {
                                        saveChanges()
                                    }) {
                                        Text("Done")
                                            .fontWeight(.medium)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        )
                .navigationBarTitle("Edit Item", displayMode: .inline)
                .allowsHitTesting(!showItemOptions)
            }
            GeometryReader { geometry in
                
                ItemOptionsView(showItemOptionsSheet: $showItemOptions, onDeleteItem: deleteItem, onEditName: {
                    isItemNameFocused = true
                }, itemName: item.metadata,
                                onDuplicateItem: duplicateItem,  onMoveItem: moveItemToPod, currentPodId: podId,
                                dismissCardDetailView: { presentationMode.wrappedValue.dismiss()})
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(y: itemOptionsOffset)
                .onChange(of: showItemOptions) { oldValue, newValue in
                    withAnimation(.snappy()) {
                        itemOptionsOffset = newValue ? 0 : geometry.size.height
                    }
                }
                
                
            }
            .edgesIgnoringSafeArea(.all)
        }
 
        .onAppear {
            itemOptionsOffset = UIScreen.main.bounds.height
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Item"),
                message: Text("Delete \(item.metadata)?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteItem()
                },
                secondaryButton: .cancel())}
        
    }
    
    // In CardDetailView
    private func logSingleItem() {
        // Create a temporary ID
        let tempId = Int.random(in: Int.min ... -1)
        
        // Convert column values to the format expected by the backend
        let convertedValues = columnValues.mapValues { value -> Any in
            convertColumnValueToAny(value)
        }
        
        // Prepare the single item data with explicit type
        let itemData: [(id: Int, notes: String?, columnValues: [String: Any])] = [(
            id: item.id,
            notes: nil,
            columnValues: convertedValues
        )]
        
        // Step 1: Create temporary activity with the negative ID
        let tempActivity = Activity(
            id: tempId,
            podId: podId,
            podTitle: podTitle,
            userEmail: viewModel.email,
            userName: viewModel.username,
            duration: 0,
            loggedAt: Date(),
            notes: logNotes,
            isSingleItem: true,
            items: [
                ActivityItem(
                    id: Int.random(in: Int.min ... -1),
                    activityId: tempId,
                    itemId: item.id,
                    itemLabel: item.metadata,
                    loggedAt: Date(),
                    notes: Optional<String>.none,
                    columnValues: columnValues  // Use the original columnValues here, not the converted ones
                )
            ]
        )
        
        // Step 2: Insert temporary activity into ActivityManager
        activityManager.activities.insert(tempActivity, at: 0)
        print("Inserted temporary single item activity with ID: \(tempId)")
        
        // Step 3: Dismiss view immediately for optimistic update
        presentationMode.wrappedValue.dismiss()
        
        // Step 4: Make the actual network request
        activityManager.createActivity(
            duration: 0,
            notes: logNotes,
            items: itemData,
            isSingleItem: true,
            tempId: tempId
        ) { result in
            DispatchQueue.main.async {
                guard self != nil else { return }
                
                switch result {
                case .success(let actualActivity):
                    print("Single item activity creation completed.")
                    
                case .failure(let error):
                    // Remove the temporary activity
                    activityManager.activities.removeAll { $0.id == tempId }
                    print("Failed to create single item activity, removed temporary activity ID: \(tempId)")
//                    self.logError = error
//                    self.showLogError = true
                }
            }
        }
    }

    private func convertColumnValueToAny(_ value: ColumnValue) -> Any {
        switch value {
        case .string(let str):
            return str
        case .number(let num):
            return num
        case .time(let timeValue):
            return timeValue
        case .array(let arr):
            return arr.map { convertColumnValueToAny($0) }
        case .null:
            return NSNull()
        }
    }
  

    // private func deleteRow(at index: Int, in columnGroup: [PodColumn]) {
    //     for column in columnGroup {
    //         if case .array(var values) = columnValues[String(column.id)] ?? .array([]) {
    //             if index < values.count {
    //                 values.remove(at: index)
    //                 columnValues[String(column.id)] = .array(values)
    //             }
    //         }
    //     }
        
    //     let groupType = columnGroup.first?.groupingType ?? ""
    //     if let currentCount = groupedRowsCount[groupType], currentCount > 0 {
    //         groupedRowsCount[groupType] = currentCount - 1
    //     }
    //     checkForChanges()
    // }
    private func deleteRow(at index: Int, in columnGroup: [PodColumn]) {
    for column in columnGroup {
        let columnId = String(column.id)
        if case .array(var values) = columnValues[columnId] {
            if index < values.count {
                values.remove(at: index)
                
                // Renumber Sets after deletion
                if column.name == "Set" {
                    values = values.enumerated().map { idx, _ in 
                        .number(Double(idx + 1))
                    }
                }
                
                var newColumnValues = columnValues
                newColumnValues[columnId] = .array(values)
                columnValues = newColumnValues
            }
        }
    }
    
    let groupType = columnGroup.first?.groupingType ?? ""
    if let currentCount = groupedRowsCount[groupType], currentCount > 0 {
        var newGroupedRowsCounts = groupedRowsCount
        newGroupedRowsCounts[groupType] = currentCount - 1
        groupedRowsCount = newGroupedRowsCounts
    }
    
    checkForChanges()
}
  



private func addRow(for columnGroup: [PodColumn]) {
    let groupType = columnGroup.first?.groupingType ?? ""
    let currentRowIndex = groupedRowsCount[groupType] ?? 1
    
    for column in columnGroup {
        let columnId = String(column.id)
        if case .array(var values) = columnValues[columnId] {
            // Special handling for "Set" column
            if column.name == "Set" {
                values.append(.number(Double(values.count + 1)))
            } else if column.type == "number" {
                values.append(values.last ?? .number(0))
            } else {
                values.append(values.last ?? .null)
            }
            
            // Force a UI update by creating a new dictionary entry
            var newColumnValues = columnValues
            newColumnValues[columnId] = .array(values)
            columnValues = newColumnValues
        } else {
            // If not array, initialize with the first value
            let initialValue: ColumnValue = column.name == "Set" ? .number(1) : (column.type == "number" ? .number(0) : .null)
            var newColumnValues = columnValues
            newColumnValues[columnId] = .array([initialValue])
            columnValues = newColumnValues
        }
    }
    
    // Force UI update for row count
    var newGroupedRowsCounts = groupedRowsCount
    newGroupedRowsCounts[groupType] = currentRowIndex + 1
    groupedRowsCount = newGroupedRowsCounts
    
    checkForChanges()
}

    
    
    private func checkForChanges() {
        hasUnsavedChanges = false
        
        // Check item name
        if itemName != item.metadata {
            hasUnsavedChanges = true
            return
        }
        
        // Check notes
        if itemNotes != (item.notes ?? "") {
            hasUnsavedChanges = true
            return
        }
        
        // Check column values including grouped columns
        for (key, value) in columnValues {
            let originalValue = item.columnValues?[key] ?? .null // Use .null as default for comparison
            
            let column = podColumns.first(where: { $0.name == key })
            let isGrouped = column?.groupingType == "grouped"
            
            if isGrouped {
                // For grouped columns, compare arrays
                if case .array(let newArray) = value,
                   case .array(let originalArray) = originalValue {
                    let newDescriptions = newArray.map { $0.description }
                    let originalDescriptions = originalArray.map { $0.description }
                    if newDescriptions != originalDescriptions {
                        hasUnsavedChanges = true
                        return
                    }
                } else if case .array(let newArray) = value, newArray.isEmpty, case .null = originalValue {
                    // Don't mark as changed if comparing empty array with null
                    continue
                } else {
                    hasUnsavedChanges = true
                    return
                }
            } else {
                // For singular columns, handle null values properly
                if case .null = value, case .null = originalValue {
                    continue
                }
                if value.description != originalValue.description {
                    hasUnsavedChanges = true
                    return
                }
            }
        }
    }

    private func moveItemToPod(_ toPodId: Int) {
        networkManager.moveItemToPod(itemId: item.id, fromPodId: podId, toPodId: toPodId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove the item from the current pod's items
                    if let index = allItems.firstIndex(where: { $0.id == item.id }) {
                        allItems.remove(at: index)
                    }
                    presentationMode.wrappedValue.dismiss()
                    // You might want to show a success message or update UI here
                case .failure(let error):
                    print("Failed to move item: \(error)")
                    // You might want to show an error message to the user here
                }
            }
        }
    }
    
    private func duplicateItem() {
        let newItem = PodItem(
            id: 0, // The server will assign the actual ID
            metadata: "\(itemName) (Copy)",
            itemType: item.itemType,
            notes: item.notes
        )
        
        networkManager.createPodItem(podId: podId, label: newItem.metadata, itemType: newItem.itemType, notes: newItem.notes, columnValues: newItem.columnValues ?? [:]) { result in
            switch result {
            case .success(let createdItem):
                DispatchQueue.main.async {
                    if let index = allItems.firstIndex(where: { $0.id == item.id }) {
                        allItems.insert(createdItem, at: index + 1)
                    } else {
                        allItems.append(createdItem)
                    }
                    print("Item duplicated successfully")
                }
            case .failure(let error):
                print("Failed to duplicate item: \(error)")
                // You might want to show an alert to the user here
            }
        }
    }
    
    
    private var addColumnButton: some View {
        HStack {
            Button(action: {
                print("add column tapped")
                showAddColumn = true
                addColumnOffset = UIScreen.main.bounds.height - 250
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .regular))
                    Text("Add column")
                        .font(.system(size: 16, weight: .regular))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 15)
                .background(Color("iosbg"))
                .foregroundColor(.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func deleteItem() {
        networkManager.deletePodItem(itemId: item.id) { success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    if let index = allItems.firstIndex(where: { $0.id == item.id }) {
                        allItems.remove(at: index)
                    }
                    presentationMode.wrappedValue.dismiss()
                    
                } else {
                    print("Failed to delete item: \(errorMessage ?? "Unknown error")")
                    // You might want to show an error alert to the user here
                }
            }
        }
    }
    

    private func addNewColumn(title: String, type: String) {

        isAddingColumn = true
        showAddColumn = false
        networkManager.addColumnToPod(podId: podId, columnName: title, columnType: type) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let column):
                    let newColumn = PodColumn(
                        id: column.id,
                        name: title,
                        type: type
                    )
                    podColumns.append(newColumn)
                    
                    // Use column ID as key instead of name
                    columnValues[String(column.id)] = .null
                    
                    if item.columnValues == nil {
                        item.columnValues = [:]
                    }
                    item.columnValues?[String(column.id)] = .null
                    
                    
                    checkForChanges()
                    showAddColumn = false
                case .failure(let error):
                    print("Failed to add new column: \(error)")
                }
            }
        }
    }
    
    private func updateVisibleColumnsOnServer() {
        networkManager.updateVisibleColumns(podId: podId, columns: visibleColumns) { result in
            switch result {
            case .success:
                print("Visible columns updated successfully")
            case .failure(let error):
                print("Failed to update visible columns: \(error)")
                // You might want to show an alert to the user here
            }
        }
    }
 
    private func saveChanges() {
        var hasChanges = false
        var updatedColumnValues: [String: ColumnValue] = [:]

        print("Starting save changes for PodItemUserValue")

        for (key, newValue) in columnValues {
//            guard let column = podColumns.first(where: { $0.name == key }) else {
//                continue
//            }
            guard let column = podColumns.first(where: { String($0.id) == key }) else {
                     continue
                 }
            let isGrouped: Bool = (column.groupingType == "grouped")

            let originalValue: ColumnValue = item.columnValues?[key] ?? .null

            var updatedValue: ColumnValue = originalValue

            if isGrouped {
                // Handle grouped columns (arrays)
                let newValuesArray: [ColumnValue]
                if case .array(let array) = newValue {
                    newValuesArray = array
                } else {
                    newValuesArray = [newValue]
                }

                let originalValuesArray: [ColumnValue]
                if case .array(let array) = originalValue {
                    originalValuesArray = array
                } else {
                    originalValuesArray = [originalValue]
                }

                let newDescriptions: [String] = newValuesArray.map { $0.description }
                let originalDescriptions: [String] = originalValuesArray.map { $0.description }

                if newDescriptions != originalDescriptions {
                    updatedValue = .array(newValuesArray)
                    hasChanges = true
                }
            } else {
                // Handle singular columns
                let newDescription: String = newValue.description
                let originalDescription: String = originalValue.description

                if newDescription != originalDescription {
                    updatedValue = newValue
                    hasChanges = true
                }
            }

            updatedColumnValues[key] = updatedValue
        }

        // Check if item name or notes have changed
        if itemName != item.metadata || itemNotes != (item.notes ?? "") {
            hasChanges = true
        }

        if hasChanges {
            print("Updating PodItemUserValue with values:", updatedColumnValues)
            networkManager.updatePodItem(
                itemId: item.id,
                newLabel: itemName,
                newNotes: itemNotes,
                newColumnValues: updatedColumnValues,
                userEmail: viewModel.email
            ) { (result: Result<Void, Error>) in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("Column values before update:", columnValues)
                        
                        // Create a new copy of the values
                           var newColumnValues: [String: ColumnValue] = [:]
                           for (key, value) in updatedColumnValues {
                               newColumnValues[key] = value
                           }

                        // Update everything at once
                           self.item.metadata = self.itemName
                           self.item.notes = self.itemNotes
                           self.item.columnValues = newColumnValues  // Use the copy
                        self.presentationMode.wrappedValue.dismiss()
                    case .failure(let error):
                        print("Failed to update pod item: \(error)")
                        // Handle the error as needed
                    }
                }
            }
        } else {
            print("No changes detected")
            self.presentationMode.wrappedValue.dismiss()
        }
    }

    

}

struct SingularColumnView: View {
    let column: PodColumn
    @Binding var columnValues: [String: ColumnValue]
    @FocusState var focusedField: String?
    @Binding var expandedColumn: String?
    let onValueChanged: () -> Void
    
    
    var body: some View {
     
        
        VStack(alignment: .leading, spacing: 5) {
            Text(column.name)
                .font(.system(size: 16))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .foregroundColor(.primary)
                .kerning(0.2)
            
            ColumnValueInputView(
                column: column,
                columnValues: $columnValues,
                focusedField: _focusedField,
                expandedColumn: $expandedColumn,
                onValueChanged: onValueChanged
            )
//            .padding(.vertical, 8)
            .background(Color("iosnp"))
            .cornerRadius(8)
        }
    }
}

struct GroupedColumnHeaderView: View {
    let columnGroup: [PodColumn]
    
    var body: some View {
        HStack(spacing: 15) {
            ForEach(columnGroup, id: \.id) { column in
                Text(column.name)
                    .font(.system(size: 16))
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundColor(.primary)
                    .kerning(0.2)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// 3. Create a view for grouped column rows
struct GroupedColumnRowView: View {
    let columnGroup: [PodColumn]
    let rowIndex: Int
    @Binding var columnValues: [String: ColumnValue]
    @FocusState var focusedField: String?
    @Binding var expandedColumn: String?
    let onDelete: () -> Void
    let onValueChanged: () -> Void
    
    
    var body: some View {
        List {
            HStack(spacing: 15) {
                ForEach(columnGroup, id: \.id) { column in
                    GroupedColumnInputView(
                                           column: column,
                                           rowIndex: rowIndex,
                                           columnValues: $columnValues,
                                           focusedField: _focusedField,
                                           expandedColumn: $expandedColumn,
                                           onValueChanged: onValueChanged
                                       )
                                       .frame(maxWidth: .infinity)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .listStyle(PlainListStyle())
        .frame(height: 44)
    }
}

// 4. Create a view for the grouped columns section
struct GroupedColumnView: View {
    let columnGroup: [PodColumn]
     @Binding var groupedRowsCount: Int
    let onAddRow: () -> Void
    let onDeleteRow: (Int) -> Void
    @Binding var columnValues: [String: ColumnValue]
    @FocusState var focusedField: String?
    @Binding var expandedColumn: String?
    let onValueChanged: () -> Void

    // init(columnGroup: [PodColumn], groupedRowsCount: Int, onAddRow: @escaping () -> Void, onDeleteRow: @escaping (Int) -> Void, columnValues: Binding<[String: ColumnValue]>, focusedField: FocusState<String?>, expandedColumn: Binding<String?>, onValueChanged: @escaping () -> Void) {
    //     self.columnGroup = columnGroup
    //     // This is where we need to ensure at least one row
    //     self._groupedRowsCount = State(initialValue: max(1, groupedRowsCount))  // Force at least 1 row
    //     self.onAddRow = onAddRow
    //     self.onDeleteRow = onDeleteRow
    //     self._columnValues = columnValues
    //     self._focusedField = focusedField
    //     self._expandedColumn = expandedColumn
    //     self.onValueChanged = onValueChanged
    // }
      init(columnGroup: [PodColumn], 
         groupedRowsCount: Binding<Int>, 
         onAddRow: @escaping () -> Void, 
         onDeleteRow: @escaping (Int) -> Void, 
         columnValues: Binding<[String: ColumnValue]>, 
         focusedField: FocusState<String?>, 
         expandedColumn: Binding<String?>, 
         onValueChanged: @escaping () -> Void) {
        self.columnGroup = columnGroup
        self._groupedRowsCount = groupedRowsCount  // Now binding directly
        self.onAddRow = onAddRow
        self.onDeleteRow = onDeleteRow
        self._columnValues = columnValues
        self._focusedField = focusedField
        self._expandedColumn = expandedColumn
        self.onValueChanged = onValueChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupedColumnHeaderView(columnGroup: columnGroup)

            // Always show at least one row
            ForEach(0..<max(1, groupedRowsCount), id: \.self) { rowIndex in
                GroupedColumnRowView(
                    columnGroup: columnGroup,
                    rowIndex: rowIndex,
                    columnValues: $columnValues,
                    focusedField: _focusedField,
                    expandedColumn: $expandedColumn,
                    onDelete: { onDeleteRow(rowIndex) },
                    onValueChanged: onValueChanged
                )
            }

            Button(action: onAddRow) {
                Text("Add Row")
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(.top, 5)
        // .onAppear {
        //     if groupedRowsCount == 0 {
        //         onAddRow()
        //     }
        // }
    }
}

struct ColumnValueInputView: View {
    let column: PodColumn
    @Binding var columnValues: [String: ColumnValue]
    @FocusState var focusedField: String?
    @Binding var expandedColumn: String?
    let onValueChanged: () -> Void
    
    var body: some View {
        let columnId = String(column.id)
        Group {
            if column.type == "text" {
                let textBinding = Binding<String>(
                    get: { columnValues[columnId]?.description ?? "" },
                    set: {
                        columnValues[columnId] = .string($0)
                        onValueChanged()
                    }
                )
                
                TextField("", text: textBinding)
                    .focused($focusedField, equals: columnId)
                    .foregroundColor(.primary)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .cornerRadius(12)
                    .background(Color("iosnp"))
            }
            else if column.type == "number" {
                let numberBinding = Binding<String>(
                    get: { columnValues[columnId]?.description ?? "" },
                    set: { newValue in
                        if let num = Double(newValue) {
                            columnValues[columnId] = .number(num)
                        } else {
                            columnValues[columnId] = .null
                        }
                        onValueChanged()
                    }
                )
                
                TextField("", text: numberBinding)
                    .focused($focusedField, equals: columnId)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .cornerRadius(12)
                    .background(Color("iosnp"))
            }
            else if column.type == "time" {
                Button(action: {
                    withAnimation {
                        expandedColumn = (expandedColumn == columnId) ? nil : columnId
                    }
                }) {
                    Text(columnValues[columnId]?.description ?? "")
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                }
                
                if expandedColumn == columnId {
                    InlineTimePicker(timeValue: Binding(
                        get: {
                            if case .time(let timeValue) = columnValues[columnId] {
                                return timeValue
                            }
                            return TimeValue(hours: 0, minutes: 0, seconds: 0)
                        },
                        set: {
                            columnValues[columnId] = .time($0)
                            onValueChanged()
                        }
                    ))
                    .frame(height: 150)
                    .transition(.opacity)
                }
            }
        }
    }
}

struct GroupedColumnInputView: View {
    let column: PodColumn
    let rowIndex: Int
    @Binding var columnValues: [String: ColumnValue]
    @FocusState var focusedField: String?
    @Binding var expandedColumn: String?
    let onValueChanged: () -> Void
    
    var body: some View {
        let columnId = String(column.id)
        
        let currentValue = columnValues[columnId] ?? .array([])
        let values: [ColumnValue] = {
            if case .array(let arr) = currentValue {
                return arr
            }
            return [currentValue]
        }()
        
        let value = rowIndex < values.count ? values[rowIndex] : .null
        
        Group {
            if column.type == "text" {
                let textBinding = Binding<String>(
                    get: { value.description },
                    set: { newValue in
                        var updatedValues = values
                        while updatedValues.count <= rowIndex {
                            updatedValues.append(.null)
                        }
                        updatedValues[rowIndex] = .string(newValue)
                        columnValues[columnId] = .array(updatedValues)
                        onValueChanged()
                    }
                )
                
                TextField("", text: textBinding)
                    .focused($focusedField, equals: "\(columnId)_\(rowIndex)")
                    .multilineTextAlignment(.center)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color("iosnp"))
                    .cornerRadius(12)
            }
            else if column.type == "number" {
                let numberBinding = Binding<String>(
                    get: { value.description },
                    set: { newValue in
                        var updatedValues = values
                        while updatedValues.count <= rowIndex {
                            updatedValues.append(.null)
                        }
                        if let num = Double(newValue) {
                            updatedValues[rowIndex] = .number(num)
                        } else {
                            updatedValues[rowIndex] = .null
                        }
                        columnValues[columnId] = .array(updatedValues)
                        onValueChanged()
                    }
                )
                
                TextField("", text: numberBinding)
                    .focused($focusedField, equals: "\(columnId)_\(rowIndex)")
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color("iosnp"))
                    .cornerRadius(12)
            }
            else if column.type == "time" {
                Button(action: {
                    withAnimation {
                        expandedColumn = (expandedColumn == "\(columnId)_\(rowIndex)") ? nil : "\(columnId)_\(rowIndex)"
                    }
                }) {
                    Text(value.description)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color("iosnp"))
                        .cornerRadius(12)
                }
                
                if expandedColumn == "\(columnId)_\(rowIndex)" {
                    InlineTimePicker(timeValue: Binding(
                        get: {
                            if case .time(let timeValue) = value {
                                return timeValue
                            }
                            return TimeValue(hours: 0, minutes: 0, seconds: 0)
                        },
                        set: { newValue in
                            var updatedValues = values
                            while updatedValues.count <= rowIndex {
                                updatedValues.append(.null)
                            }
                            updatedValues[rowIndex] = .time(newValue)
                            columnValues[columnId] = .array(updatedValues)
                            onValueChanged()
                        }
                    ))
                    .frame(height: 150)
                    .transition(.opacity)
                }
            }
        }
    }
}
