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
                                           
                                           Text(column.name)
                                               .foregroundColor(.primary)
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
                                                                     columnToDelete = column
                                                                     showDeleteConfirmation = true
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
            .navigationBarItems(
                leading: Button("Cancel") {
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
        .confirmationDialog(
            "Delete \(columnToDelete?.name ?? "")?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let column = columnToDelete {
                    deleteColumn(column)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    
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
    
    private func updateColumnGrouping(index: Int, groupingType: String) {
        let columnName = podColumns[index].name
        podColumns[index].groupingType = groupingType
        hasUnsavedChanges = true
        
        networkManager.updateColumnGrouping(podId: podId, columnName: columnName, groupingType: groupingType) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Column grouping updated successfully.")
                case .failure(let error):
                    print("Failed to update column grouping: \(error.localizedDescription)")
                    podColumns[index].groupingType = podColumns[index].groupingType
                }
            }
        }
        selectedMenuColumn = nil
    }
    

    
//        private func saveChanges() {
//            networkManager.updateVisibleColumns(podId: podId, columns: visibleColumns) { result in
//                DispatchQueue.main.async {
//                    switch result {
//                    case .success:
//                        saveColumnOrder()
//                        isPresented = false
//                    case .failure(let error):
//                        print("Failed to update visible columns: \(error)")
//                        // Here you might want to show an alert to the user
//                    }
//                }
//            }
//        }
    private func saveChanges() {
        let columnOrder = podColumns.map { $0.name }
        networkManager.updateColumnOrder(podId: podId, columnOrder: columnOrder) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    networkManager.updateVisibleColumns(podId: podId, columns: visibleColumns) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                isPresented = false
                            case .failure(let error):
                                print("Failed to update visible columns: \(error)")
                            }
                        }
                    }
                case .failure(let error):
                    print("Failed to update column order: \(error)")
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
                case .success:
                    let newColumn = PodColumn(name: title, type: type)
                    podColumns.append(newColumn)
                    
                    showAddColumn = false
                    hasUnsavedChanges = true
                case .failure(let error):
                    print("Failed to add new column: \(error)")
                    // Here you might want to show an alert to the user
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
