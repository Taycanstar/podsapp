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
    

    @Binding var visibleColumns: [String]

    var body: some View {
        NavigationView {
            ZStack {
                Color("mdBg").edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(podColumns, id: \.name) { column in
                                HStack {
                                    Button(action: {
                                        toggleColumnVisibility(column.name)
                                    }) {
                                        Image(systemName: visibleColumns.contains(column.name) ? "checkmark.square.fill" : "square")
                                            .foregroundColor(visibleColumns.contains(column.name) ? .accentColor : .gray)
                                    }
                                    .disabled(visibleColumns.count == 3 && !visibleColumns.contains(column.name))
                                    
                                    Text(column.name)
                                    Spacer()
                                    Button(action: {
                                        columnToDelete = column
                                        showDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical)
                                .background(Color("ltBg").cornerRadius(10))
                            }
                            
                            Text("Select up to 3 columns to display in the list view")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.top, 10)
                            addColumnButton
                                .padding(.top, 10)
                        }
                        .padding(.horizontal, 15)
                        .padding(.top, 15)
                    }
                  
                }
                .background(Color("mdBg"))
                
                
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
                trailing: Button("Save") {
                    saveChanges()
                }
            )
        }
        .background(Color("mdBg"))
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
    
    private func toggleColumnVisibility(_ columnName: String) {
            if visibleColumns.contains(columnName) {
                visibleColumns.removeAll { $0 == columnName }
            } else if visibleColumns.count < 3 {
                visibleColumns.append(columnName)
            }
        }
        
        private func saveChanges() {
            networkManager.updateVisibleColumns(podId: podId, columns: visibleColumns) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        isPresented = false
                    case .failure(let error):
                        print("Failed to update visible columns: \(error)")
                        // Here you might want to show an alert to the user
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
            .background(Color("mdBg"))
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
                    
//                    // Automatically make the new column visible if there are fewer than 3 visible columns
//                                      if visibleColumns.count < 3 {
//                                          visibleColumns.append(title)
//                                          updateVisibleColumnsOnServer()
//                                      }
                    showAddColumn = false
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
