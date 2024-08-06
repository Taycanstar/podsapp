//
//  PodOptionsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/4/24.
//

import SwiftUI

struct PodOptionsView: View {
    @Binding var showPodOptionsSheet: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
     var onDeletePod: () -> Void
     var podName: String
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.6))
                .frame(width: 35, height: 4)
                .padding(.top, 10)
            
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .foregroundColor(.primary)
                    
                }
            }
            
            VStack(alignment: .leading, spacing: 0) {
                MenuItemView(iconName: "square.and.arrow.up", text: "Share", action: {
                    print("Tapped Share")
                    showPodOptionsSheet = false
                }, color: .primary)
                
                MenuItemView(iconName: "person.2", text: "Pod members", action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("Tapped pod members")
                    }
                }, color: .primary)
                
                MenuItemView(iconName: "info.circle", text: "Pod info", action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("Tapped pod info")
                    }
                }, color: .primary)
                
                MenuItemView(iconName: "bubble", text: "Pod Chat", action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("Tapped Pod chat")
                    }
                }, color: .primary)
                
                MenuItemView(iconName: "bolt.horizontal.circle", text: "Activity Log", action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("Tapped Pod activity")
                    }
                }, color: .primary)
//                
//                MenuItemView(iconName: "gauge.with.needle", text: "Progress Tracker", action: {
//                    dismiss()
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                        print("Tapped Progress")
//                    }
//                }, color: .primary)
                
                Divider().padding(.vertical, 5)
                
                MenuItemView(iconName: "trash", text: "Delete Pod", action: {
              
                        showDeleteConfirmation = true
                 
                }, color: .red)
            }
            .padding(.horizontal, 25)
            .padding(.top, 20)
            .padding(.bottom, 15)
        
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .confirmationDialog("Delete \"\(podName)\"? ",
                                isPresented: $showDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDeletePod()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}


struct MenuItemView: View {
    let iconName: String
    let text: String
    let action: () -> Void
    let color: Color

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .frame(width: 24, alignment: .center)  // Fixed width for all icons
                    .foregroundColor(color)
                
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(color)
                
                Spacer()
            }
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
