//
//  AddSheetView.swift
//  Podstack
//
//  Created by Dimi Nunez on 7/29/24.
//

import SwiftUI

struct AddSheetView: View {
    @Binding var showAddSheet: Bool
    @Binding var showingVideoCreationScreen: Bool
    @Environment(\.dismiss) private var dismiss
    @Binding var showQuickPodView: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Add")
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 20)
                .padding(.bottom, 10)
            Divider()
            
            VStack(alignment: .leading, spacing: 7) {
                Button(action: {
                    print("Tapped New Item")
                    showAddSheet = false
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("New Item")
                            .padding(.horizontal, 10)
                            .font(.system(size: 15))
                    }
                    .padding(.vertical, 8)
                    .foregroundColor(Color(UIColor.label))
                    .background(Color(UIColor.systemBackground))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                Button(action: {
                    dismiss() // This will dismiss the current sheet
                                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                      showQuickPodView = true
                                  }
                }) {
                    HStack {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 20))
                        Text("Quick Pod")
                            .padding(.horizontal, 10)
                            .font(.system(size: 15))
                    }
                    .padding(.vertical, 8)
                    .foregroundColor(Color(UIColor.label))
                    .background(Color(UIColor.systemBackground))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                Button(action: {
                    dismiss()  // This will dismiss the sheet
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showingVideoCreationScreen = true
                                    }
                }) {
                    HStack {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 20))
                        Text("Standard Pod")
                            .padding(.horizontal, 10)
                            .font(.system(size: 15))
                    }
                    .padding(.vertical, 8)
                    .foregroundColor(Color(UIColor.label))
                    .background(Color(UIColor.systemBackground))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 10)
            .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
    
    }
}
