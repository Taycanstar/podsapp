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

    var body: some View {
        NavigationView {
            ZStack {
                Color("mdBg").edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 10) {
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
                                .background(Color("ltBg").cornerRadius(10))
                            }
                            
                            addColumnButton
                                .padding(.top, 10)
                        }
                        .padding(.horizontal, 15)
                        .padding(.top, 15)
                    }
                }
                .background(Color("mdBg"))
                
                GeometryReader { geometry in
                    AddColumnView(isPresented: $showAddColumn, onAddColumn: addNewColumn)
                        .offset(y: showAddColumn ? geometry.size.height - 300 : geometry.size.height + 300)
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
                    showAddColumn = false
                case .failure(let error):
                    print("Failed to add new column: \(error)")
                    // Here you might want to show an alert to the user
                }
            }
        }
    }
}
