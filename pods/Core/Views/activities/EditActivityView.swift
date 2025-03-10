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
        self.log = log
        self.columns = columns
        self.onSave = onSave
        
        var initialColumnValues: [String: ColumnValue] = [:]
        var initialGroupedRowsCount: [String: Int] = [:]
        
        // It's already ID-based, so just copy directly
        initialColumnValues = log.columnValues
        
        // Set up grouped counts
        for column in columns {
            if column.groupingType == "grouped",
               case .array(let values) = log.columnValues[String(column.id)] ?? .null {
                initialGroupedRowsCount[column.groupingType ?? ""] = values.count
            }
        }
        
        _columnValues = State(initialValue: initialColumnValues)
        _activityNote = State(initialValue: log.notes)
        _showNotesInput = State(initialValue: !log.notes.isEmpty)
        _groupedRowsCount = State(initialValue: initialGroupedRowsCount)
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
//            guard !skippedColumns.contains(column.id) else { continue }
            
            if case .array(let existingValues) = columnValues[String(column.id)] {
                var values = existingValues
                
                // Determine the new value based on column type
                let newValue: ColumnValue
                if column.type == "number" {
                    if case .number(1.0) = values.first {
                        newValue = .number(Double(values.count + 1))
                    } else {
                        newValue = values.last ?? .null
                    }
                } else {
                    newValue = values.last ?? .null
                }
                
                values.append(newValue)
                columnValues[String(column.id)] = .array(values)
            } else {
                columnValues[String(column.id)] = .array([.null])
            }
        }
        
        groupedRowsCount[groupType] = currentRowIndex + 1
    }
    
    private func deleteRow(at index: Int, in columnGroup: [PodColumn]) {
        for column in columnGroup {
            if case .array(var values) = columnValues[String(column.id)] {
                if index < values.count {
                    values.remove(at: index)
                    columnValues[String(column.id)] = .array(values)
                }
            }
        }
        
        let groupType = columnGroup.first?.groupingType ?? ""
        if let currentCount = groupedRowsCount[groupType], currentCount > 0 {
            groupedRowsCount[groupType] = currentCount - 1
        }
    }

    private func updateActivity() {
        isSubmitting = true
        print("About to send to API - columnValues:", columnValues)
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
                                  onSave(updatedLog)
                                  print("After onSave called - was this the last thing that happened?")
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
}
