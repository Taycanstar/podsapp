//
//  NewItemPop.swift
//  Pods
//
//  Created by Dimi Nunez on 12/8/24.
//
import SwiftUI

struct NewItemPop: View {
    @Binding var showAddSheet: Bool
    @Binding var showingVideoCreationScreen: Bool
    @Environment(\.dismiss) private var dismiss
    @Binding var showQuickPodView: Bool
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 35, height: 4)
                    .padding(.top, 10)
                Text("Add")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.top, 15)
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
                        .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
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
                            Text("New Pod")
                                .padding(.horizontal, 10)
                                .font(.system(size: 15))
                        }
                        .padding(.vertical, 8)
                        .foregroundColor(Color(UIColor.label))
                        .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
            
                }
                .padding(.horizontal, 15)
                .padding(.top, 10)
                .padding(.bottom, 15)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(colorScheme == .dark ? Color(rgb: 44,44,44) : .white)
            .cornerRadius(20)
            
        }
    }
}
