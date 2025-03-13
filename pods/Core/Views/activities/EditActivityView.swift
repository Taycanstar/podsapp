//
//  EditActivityView.swift
//  Pods
//
//  Created by Dimi Nunez on 12/12/24.
//

import SwiftUI


struct EditActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let log: PodItemActivityLog
    let columns: [PodColumn]
    let onSave: (PodItemActivityLog) -> Void
    
    @State private var columnValues: [String: ColumnValue]
    @State private var activityNote: String
    @State private var expandedColumn: String?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showNotesInput: Bool
    @FocusState private var focusedField: String?
    @State private var groupedRowsCount: [String: Int] = [:]
    @EnvironmentObject var viewModel: OnboardingViewModel

    init(log: PodItemActivityLog, columns: [PodColumn], onSave: @escaping (PodItemActivityLog) -> Void) {
        print("EditActivityView init - received log values:", log.columnValues)
        print("EditActivityView init - columns:", columns.map { "\($0.id):\($0.name)" })
        
        self.log = log
        self.columns = columns
        self.onSave = onSave
        
        var initialColumnValues: [String: ColumnValue] = [:]
        var initialGroupedRowsCount: [String: Int] = [:]
        
        // It's already ID-based, so just copy directly
        initialColumnValues = log.columnValues
        
        // First pass: try exact matches for grouped columns
        for column in columns {
            if column.groupingType == "grouped" {
                let columnIdStr = String(column.id)
                if case .array(let values) = log.columnValues[columnIdStr] ?? .null {
                    initialGroupedRowsCount[column.groupingType ?? ""] = values.count
                }
            }
        }
        
        // If we didn't find any grouped counts, look for any array values
        if initialGroupedRowsCount.isEmpty {
            // Find any keys with array values
            let arrayKeys = log.columnValues.keys.filter { key in
                if case .array = log.columnValues[key] {
                    return true
                }
                return false
            }
            
            if !arrayKeys.isEmpty {
                // Get the max count from any array values
                var maxArrayCount = 0
                for key in arrayKeys {
                    if case .array(let values) = log.columnValues[key] {
                        maxArrayCount = max(maxArrayCount, values.count)
                    }
                }
                
                // Set the same count for all grouped columns
                for column in columns where column.groupingType == "grouped" {
                    initialGroupedRowsCount[column.groupingType ?? ""] = maxArrayCount
                }
            } else {
                // Default to 1 row if we couldn't find any array values
                for column in columns where column.groupingType == "grouped" {
                    initialGroupedRowsCount[column.groupingType ?? ""] = 1
                }
            }
        }
        
        _columnValues = State(initialValue: initialColumnValues)
        _activityNote = State(initialValue: log.notes)
        _showNotesInput = State(initialValue: !log.notes.isEmpty)
        _groupedRowsCount = State(initialValue: initialGroupedRowsCount)
        
        print("EditActivityView init - initialized columnValues:", initialColumnValues.keys)
        print("EditActivityView init - initialized groupedRowsCount:", initialGroupedRowsCount)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Reuse the column groups view from LogActivityView
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
                            // GroupedColumnView(
                            //     columnGroup: columnGroup,
                            //     groupedRowsCount: groupedRowsCount[columnGroup.first?.groupingType ?? ""] ?? 1,
                            //     onAddRow: {
                            //         withAnimation {
                            //             addRow(for: columnGroup)
                            //         }
                            //     },
                            //     onDeleteRow: { rowIndex in
                            //         withAnimation {
                            //             deleteRow(at: rowIndex, in: columnGroup)
                            //         }
                            //     },
                            //     columnValues: $columnValues,
                            //     focusedField: _focusedField,
                            //     expandedColumn: $expandedColumn,
                            //     onValueChanged: { }
                            // )
                            // In the ForEach where GroupedColumnView is called, change to:
                                GroupedColumnView(
                                    columnGroup: columnGroup,
                                    groupedRowsCount: Binding(
                                        get: { groupedRowsCount[columnGroup.first?.groupingType ?? ""] ?? 1 },
                                        set: { newValue in
                                            groupedRowsCount[columnGroup.first?.groupingType ?? ""] = newValue
                                        }
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
                                    onValueChanged: { }
                                )
                        }
                    }
                    
                    // Notes section
                    if showNotesInput {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Notes")
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 5)
                                .kerning(0.2)
                            
                            CustomTextEditor(text: $activityNote, backgroundColor: UIColor(Color("iosnp")))
                                .frame(height: 100)
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                                .background(Color("iosnp"))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .background(Color("iosbg").edgesIgnoringSafeArea(.all))
            .navigationTitle("Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Done") {
                    updateActivity()
                }
            )
            .toolbar {
                      ToolbarItemGroup(placement: .keyboard) {
                          Button("Clear") {
                              if let focusedField = focusedField {
                                  let components = focusedField.split(separator: "_").map(String.init)
                                  if components.count == 2,
                                     let rowIndexInt = Int(components[1]) {
                                      // Handle grouped columns
                                      let columnName = String(components[0])
                                      if let currentValue = columnValues[columnName],
                                         case .array(var values) = currentValue {
                                          if rowIndexInt < values.count {
                                              values[rowIndexInt] = .null
                                              columnValues[columnName] = .array(values)
                                          }
                                      }
                                  } else {
                                      // Handle singular columns
                                      columnValues[focusedField] = .null
                                  }
                              }
                          }
                          .foregroundColor(.accentColor)
                          
                          Spacer()
                          
                          Button("Done") {
                              focusedField = nil
                          }
                          .foregroundColor(.accentColor)
                          .fontWeight(.medium)
                      }
                  }
        }
    }
    
    private func groupColumns(_ columns: [PodColumn]) -> [[PodColumn]] {
        let groupedColumns = columns.filter { $0.groupingType == "grouped" }
        let singularColumns = columns.filter { $0.groupingType == "singular" }
        return [groupedColumns, singularColumns].filter { !$0.isEmpty }
    }
    
    // Reuse the same row manipulation functions from LogActivityView
    private func addRow(for columnGroup: [PodColumn]) {
        let groupType = columnGroup.first?.groupingType ?? ""
        let currentRowIndex = groupedRowsCount[groupType] ?? 1
        
        for column in columnGroup {
            let key = String(column.id)
            
            // Try to find if this column already has values
            if case .array(let existingValues) = columnValues[key] {
                var values = existingValues
                
                // Determine the new value based on column type
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
                // If no existing value found, create a new array with a null value
                columnValues[key] = .array([.null])
            }
        }
        
        groupedRowsCount[groupType] = currentRowIndex + 1
        
        // Debug what happened
        print("Added row to columns: \(columnGroup.map { $0.id })")
        print("Updated columnValues keys: \(columnValues.keys)")
    }
    
    private func deleteRow(at index: Int, in columnGroup: [PodColumn]) {
        for column in columnGroup {
            let key = String(column.id)
            
            // Only modify the column if it has an array value
            if case .array(var values) = columnValues[key] {
                if index < values.count {
                    values.remove(at: index)
                    
                    // If the array becomes empty, set it to at least have one null value
                    if values.isEmpty {
                        values = [.null]
                    }
                    
                    columnValues[key] = .array(values)
                }
            }
        }
        
        let groupType = columnGroup.first?.groupingType ?? ""
        if let currentCount = groupedRowsCount[groupType], currentCount > 1 {
            groupedRowsCount[groupType] = currentCount - 1
        } else {
            // Ensure we always have at least one row
            groupedRowsCount[groupType] = 1
        }
        
        // Debug what happened
        print("Deleted row \(index) from columns: \(columnGroup.map { $0.id })")
        print("Updated columnValues keys: \(columnValues.keys)")
    }

    private func updateActivity() {
        isSubmitting = true
        print("About to send to API - columnValues:", columnValues)
        print("About to send to API - available keys:", columnValues.keys)
        
        // Convert back to name-based values for the API
        NetworkManager().updateActivityLog(
            logId: log.id,
            columnValues: columnValues,
            notes: activityNote
        ) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success(let updatedLog):
                    print("Received from API - updatedLog.columnValues:", updatedLog.columnValues)
                    print("Received from API - keys:", updatedLog.columnValues.keys)
                    onSave(updatedLog)
                    print("After onSave called - was this the last thing that happened?")
                    dismiss()
                case .failure(let error):
                    print("API error:", error.localizedDescription)
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
}
