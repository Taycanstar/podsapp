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
    @State private var addColumnOffset: CGFloat = UIScreen.main.bounds.height + 250
    @Environment(\.colorScheme) var colorScheme
    var podId: Int
    var networkManager: NetworkManager
    
    @State private var columnToDelete: PodColumn?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationView {
            ZStack {
                Color("mdBg").edgesIgnoringSafeArea(.all)
                
                VStack {
                    List {
                        ForEach(podColumns, id: \.name) { column in
                            HStack {
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
                            .background(Color("ltBg").cornerRadius(10)) // Rounded corners for each row
                                     .listRowSeparator(.hidden) // Hide the default separators
                                     .padding(.vertical, -5)
                        }
                        .listRowBackground(Color.clear)
                       
                    }
//                    .padding()
                    .listStyle(PlainListStyle())
               
                    .background(Color("mdBg"))
                    
                    Button(action: {
                        showAddColumn = true
                        addColumnOffset = UIScreen.main.bounds.height - 250
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Column")
                        }
                    }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom)
                }
                
                GeometryReader { geometry in
                    AddColumnView(isPresented: $showAddColumn, onAddColumn: addNewColumn)
                        .offset(y: showAddColumn ? geometry.size.height - 250 : geometry.size.height + 250)
                        .animation(.snappy)
                }
            }
            .navigationBarTitle("Pod Columns", displayMode: .inline)
            .navigationBarItems(leading: Button("Close") {
                isPresented = false
            })
        }
        .background(Color("mdBg"))
        .confirmationDialog(
            "Are you sure you want to delete this column?",
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
                    showAddColumn = false
                case .failure(let error):
                    print("Failed to add new column: \(error)")
                    // Here you might want to show an alert to the user
                }
            }
        }
    }
}
