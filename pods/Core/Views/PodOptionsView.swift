//
//  PodOptionsView.swift
//  Podstack
//
//  Created by Dimi Nunez on 8/4/24.
//

import SwiftUI

struct PodOptionsView: View {
    @Binding var showPodOptionsSheet: Bool
    @Binding var showingVideoCreationScreen: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                           .fill(Color.secondary.opacity(0.6))
                           .frame(width: 35, height: 4)
                           .padding(.top, 10)
            
            HStack {
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 20))
            }
          
            
            VStack(alignment: .leading, spacing: 7) {
                Button(action: {
                    print("Tapped Share")
                    showPodOptionsSheet = false
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                        Text("Share")
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
                                      print("Tapped pod members")
                                  }
                }) {
                    HStack {
                        Image(systemName: "person.2")
                            .font(.system(size: 20))
                        Text("Pod members")
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
                                      print("Tapped pod info")
                                  }
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                        Text("Pod info")
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
                                        print("Tapped Pod chat")
                                    }
                }) {
                    HStack {
                        Image(systemName: "bubble")
                            .font(.system(size: 20))
                        Text("Pod Chat")
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
                                        print("Tapped Pod activity")
                                    }
                }) {
                    HStack {
                        Image(systemName: "bolt.horizontal.circle")
                            .font(.system(size: 20))
                        Text("Activity Log")
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
                                        print("Tapped Progress")
                                    }
                }) {
                    HStack {
                        Image(systemName: "gauge.with.needle")
                            .font(.system(size: 20))
                        Text("Progress Tracker")
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
                                        print("Tapped delete")
                                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                        Text("Delete Pod")
                            .padding(.horizontal, 10)
                            .font(.system(size: 15))
                            .foregroundColor(.red)
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
