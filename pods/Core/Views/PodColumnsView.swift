//
//  PodColumnsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/15/24.
//

import SwiftUI

struct PodColumnsView: View {
    @Binding var podColumns: [PodColumn]
    @Binding var isPresented: Bool
    @State private var showAddColumn = false
    @State private var addColumnOffset: CGFloat = UIScreen.main.bounds.height + 300
    @Environment(\.colorScheme) var colorScheme
    var podId: Int
    var networkManager: NetworkManager
    
    @State private var columnToDelete: PodColumn?
    @State private var showDeleteConfirmation = false
    
    @State private var hasUnsavedChanges = false
    @Binding var visibleColumns: [String]
    @State private var selectedMenuColumn: String?
    @State private var editedNames: [String: String] = [:]
    
    @State private var originalColumns: [PodColumn] = []
    @State private var originalVisibleColumns: [String] = []

    var body: some View {
        NavigationView {
                   ZStack {
                       Color("iosbg").edgesIgnoringSafeArea(.all)
                       
                       VStack(spacing: 0) {
                           List {
                               Section {
                                   ForEach(Array(podColumns.enumerated()), id: \.element.name) { index, column in
                                       HStack {
                                           Button(action: {
                                               toggleColumnVisibility(column.name)
                                           }) {
                                               Image(systemName: visibleColumns.contains(column.name) ? "checkmark.square.fill" : "square")
                                                   .foregroundColor(visibleColumns.contains(column.name) ? .accentColor : .gray)
                                           }
                                           .disabled(visibleColumns.count == 3 && !visibleColumns.contains(column.name))
                                           
//                                           Text(column.name)
//                                               .foregroundColor(.primary)
                                           TextField("", text: Binding(
                                               get: { editedNames[column.name] ?? column.name },
                                               set: { newValue in
                                                   editedNames[column.name] = newValue
                                                   hasUnsavedChanges = true
                                               }
                                           ))
                                           Spacer()
                                           Menu {
                                               Button("Singular") {
                                                   updateColumnGrouping(index: index, groupingType: "singular")
                                               }
                                               Button("Grouped") {
                                                   updateColumnGrouping(index: index, groupingType: "grouped")
                                               }
                                           } label: {
                                               HStack(spacing: 4) {
                                                   Text(column.groupingType.map { $0.capitalized } ?? "Singular")
                                                       .foregroundColor(.gray)
                                                       .font(.system(size: 14))
                                                       .fontWeight(.medium)
                                                   Image(systemName: selectedMenuColumn == column.name ? "chevron.up" : "chevron.down")
                                                       .foregroundColor(.gray)
                                                       .font(.system(size: 12))
                                               }
                                           }
                                           .simultaneousGesture(TapGesture().onEnded {
                                               withAnimation {
                                                   selectedMenuColumn = selectedMenuColumn == column.name ? nil : column.name
                                               }
                                           })
                                       
//                                           Button(action: {
//                                               columnToDelete = column
//                                               showDeleteConfirmation = true
//                                           }) {
//                                               Image(systemName: "trash")
//                                                   .foregroundColor(.red)
//                                           }
                                       }
                                       .padding(.vertical, 12) // Increase vertical padding here
                                       .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                       .contentShape(Rectangle())
                                       .buttonStyle(PlainButtonStyle())
                                   }
                                   .onMove { source, destination in
                                       podColumns.move(fromOffsets: source, toOffset: destination)
                                       hasUnsavedChanges = true
                                   }
                                   .onDelete { indexSet in
                                       if let index = indexSet.first {
                                                     let column = podColumns[index]
                                                     podColumns.remove(at: index)
                                                     hasUnsavedChanges = true
                                                     // Remove from visible columns if needed
                                                     if let visibleIndex = visibleColumns.firstIndex(of: column.name) {
                                                         visibleColumns.remove(at: visibleIndex)
                                                     }
                                                     // Remove from edited names if needed
                                                     editedNames.removeValue(forKey: column.name)
                                                 }
                                                             }
                                                             .listRowBackground(Color("iosnp"))
                      
                                   
                               }
                               
                           
                               Text("Select up to 3 columns to display in the list view")
                                                     .font(.caption)
                                                     .foregroundColor(.gray)
                                                     .frame(maxWidth: .infinity)
                                                     .listRowBackground(Color.clear)
                                                     .padding(.top, -10) // Negative padding reduces space
                                                     .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                                 
                                                 Section {
                                                     HStack {
                                                         Spacer()
                                                         Button(action: {
                                                             print("add column tapped")
                                                             showAddColumn = true
                                                             addColumnOffset = UIScreen.main.bounds.height - 300
                                                         }) {
                                                             HStack(spacing: 5) {
                                                                 Image(systemName: "plus.circle.fill")
                                                                     .font(.system(size: 20, weight: .regular))
                                                                 Text("Add column")
                                                                     .font(.system(size: 16, weight: .semibold))
                                                             }
                                                             .foregroundColor(.accentColor)
                                                         }
                                                         Spacer()
                                                     }
                                                     .listRowBackground(Color("iosbg"))
                                                 }
                                             
                            
                                                   }
                                                   .listStyle(InsetGroupedListStyle())
                                                   .environment(\.editMode, .constant(.inactive))
                  
                                            }
                .background(Color("iosbg"))
                
                .sheet(isPresented: $showAddColumn) {
                    AddColumnView(isPresented: $showAddColumn, onAddColumn: addNewColumn)
                        .presentationDetents([.height(UIScreen.main.bounds.height / 3.5)])
                }
            }
            .navigationBarTitle("Pod Columns", displayMode: .inline)
            .onAppear {
                           // Store original state when view appears
                           originalColumns = podColumns
                           originalVisibleColumns = visibleColumns
                       }
            .navigationBarItems(
                leading: Button("Cancel") {
                    podColumns = originalColumns
                                      visibleColumns = originalVisibleColumns
                                      editedNames = [:]
                                      isPresented = false
                },
                trailing: Group {
                    if hasUnsavedChanges {
                        Button("Done") {
                            saveChanges()
                            hasUnsavedChanges = false
                        }
                    }
                }
            )
        }
        .background(Color("iosbg"))
    
    }
    
    // Existing methods modified to track changes
    private func toggleColumnVisibility(_ columnName: String) {
        if visibleColumns.contains(columnName) {
            visibleColumns.removeAll { $0 == columnName }
        } else if visibleColumns.count < 3 {
            visibleColumns.append(columnName)
        }
        hasUnsavedChanges = true
        HapticFeedback.generateLigth()
    }
    
    // Modify updateColumnGrouping to not make backend calls
        private func updateColumnGrouping(index: Int, groupingType: String) {
            podColumns[index].groupingType = groupingType
            hasUnsavedChanges = true
            selectedMenuColumn = nil
        }

    private func saveChanges() {
        // Create a mapping of old names to new names
        let nameChanges = editedNames.filter { oldName, newName in
            oldName != newName
        }
        
        // Update visibleColumns before updating the columns
        for (oldName, newName) in nameChanges {
            if let index = visibleColumns.firstIndex(of: oldName) {
                visibleColumns[index] = newName
            }
        }
        
        networkManager.updatePodColumns(
            podId: podId,
            columns: podColumns.map { column in
                var updatedColumn = column
                if let newName = editedNames[column.name] {
                    updatedColumn.name = newName
                }
                return updatedColumn
            },
            visibleColumns: visibleColumns
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    // Update the column names in podColumns
                    for (oldName, newName) in nameChanges {
                        if let index = podColumns.firstIndex(where: { $0.name == oldName }) {
                            podColumns[index].name = newName
                        }
                    }
                    self.hasUnsavedChanges = false
                    self.isPresented = false
                case .failure(let error):
                    print("Error saving columns: \(error)")
                }
            }
        }
    }
    
    private var addColumnButton: some View {
        Button(action: {
            print("add column tapped")
            showAddColumn = true
            addColumnOffset = UIScreen.main.bounds.height - 300
            
        }) {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .regular))
                Text("Add column")
                    .font(.system(size: 14, weight: .regular))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(Color("iosbg"))
            .foregroundColor(.accentColor)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func deleteColumn(_ column: PodColumn) {
        networkManager.deleteColumnFromPod(podId: podId, columnName: column.name) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = podColumns.firstIndex(where: { $0.name == column.name }) {
                        podColumns.remove(at: index)
                        hasUnsavedChanges = true
                    }
                case .failure(let error):
                    print("Failed to delete column: \(error)")
                    // Here you might want to show an alert to the user
                }
            }
        }
    }


    private func addNewColumn(title: String, type: String) {
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
               
                    hasUnsavedChanges = true
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
                   // Here you might want to show an alert to the user
               }
           }
       }
}
