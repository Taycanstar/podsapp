//
//  NewSheetView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/1/25.
//

import SwiftUI


struct NewSheetView: View {
    @Binding var showNewSheet: Bool
    @Binding var showingVideoCreationScreen: Bool
    @Binding var showQuickPodView: Bool

    let options = [
        ("Pod", "plus.circle"),
        ("Pod from template", "goforward.plus"),
        ("Log Food", "magnifyingglass"),
        ("Voice Log", "mic")
    ]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .frame(width: 36, height: 2)
                .foregroundColor(Color("grabber"))
                .padding(.top, 8)
            
            Text("New")
                .font(.system(size: 16, weight: .semibold))
                .padding(.vertical, 16)
            
            Divider()
            
            ForEach(options, id: \.0) { option in
                HStack(spacing: 15) {
                    HStack(spacing: 15) {
                        Image(systemName: option.1)
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                            .frame(width: 30)
                            .padding(.leading, 20)
                        
                        Text(option.0)
                            .font(.system(size: 16))
                            .padding(.vertical, 12)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .background(Color(.systemBackground))
                .onTapGesture {
                    // Handle tap
                    switch option.0 {
                      case "Pod":
                          showNewSheet = false  // Close current sheet
                          showQuickPodView = true
                      default:
                          break
                      }
                }
                
                if option.0 != options.last?.0 {
                    Divider()
                        .frame(height: 0.5)
                        .padding(.leading, 65)
                }
            }
            
            Spacer()
        }
    }
}
