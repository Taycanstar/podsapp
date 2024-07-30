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
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Add")
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 20)
                .padding(.bottom, 10)
            Divider()
            
            VStack(alignment: .leading, spacing: 5) {
                Button(action: {
                    print("Tapped New Item")
                    showAddSheet = false
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("New Item")
                            .padding(.horizontal, 10)
                    }
                    .padding(.vertical, 8)
                    .foregroundColor(Color(UIColor.label))
                    .background(Color(UIColor.systemBackground))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                Button(action: {
                    print("Tapped Quick Pod")
                    showAddSheet = false
                }) {
                    HStack {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 20))
                        Text("Quick Pod")
                            .padding(.horizontal, 10)
                    }
                    .padding(.vertical, 8)
                    .foregroundColor(Color(UIColor.label))
                    .background(Color(UIColor.systemBackground))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                Button(action: {
                    showingVideoCreationScreen = true
                    showAddSheet = false
                }) {
                    HStack {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 20))
                        Text("Standard Pod")
                            .padding(.horizontal, 10)
                    }
                    .padding(.vertical, 8)
                    .foregroundColor(Color(UIColor.label))
                    .background(Color(UIColor.systemBackground))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
    }
}
