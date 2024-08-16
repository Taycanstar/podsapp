//
//  ItemOptionsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/15/24.
//


import SwiftUI

struct ItemOptionsView: View {
    @Binding var showItemOptionsSheet: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
     var onDeleteItem: () -> Void
    var onEditName: () -> Void
     var itemName: String
    var onDuplicateItem: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
   
            ZStack {
                (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                    .edgesIgnoringSafeArea(.all) 
       
                
                VStack(spacing: 0) {
                    
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            showItemOptionsSheet = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                                .foregroundColor(.primary)
                            
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        MenuItemView(iconName: "square.and.pencil", text: "Edit name", action: {
                            print("Tapped edit name")
                            showItemOptionsSheet = false
                            onEditName()
                        }, color: .primary)
                        
                        MenuItemView(iconName: "doc.on.doc", text: "Duplicate item", action: {
                            showItemOptionsSheet = false
                            onDuplicateItem()
                        }, color: .primary)
                        
                        MenuItemView(iconName: "arrow.forward.square", text: "Move to Pod", action: {
                            showItemOptionsSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                print("Tapped move to pod")
                            }
                        }, color: .primary)
                        
                        
                        Divider().padding(.vertical, 5)
                        
                        MenuItemView(iconName: "trash", text: "Delete item", action: {
                            
                            showDeleteConfirmation = true
                            
                        }, color: .red)
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    .padding(.bottom, 15)
                    
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                .cornerRadius(20)
                .confirmationDialog("Delete \"\(itemName)\"? ",
                                    isPresented: $showDeleteConfirmation,
                                    titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        onDeleteItem()
                        showItemOptionsSheet = false
                    }
                    Button("Cancel", role: .cancel) {}
                }

        }
        
    }
}
