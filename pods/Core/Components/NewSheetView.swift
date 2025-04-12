//
//  NewSheetView.swift
//  Pods
//
//  Created by Dimi Nunez on 2/1/25.
//

import SwiftUI


struct NewSheetView: View {
    @Binding var isPresented: Bool
    @Binding var showingVideoCreationScreen: Bool
    @Binding var showQuickPodView: Bool
    @Binding var selectedTab: Int 
    @EnvironmentObject var viewModel: OnboardingViewModel
    

    let options = [
        ("Log Food", "magnifyingglass"),
        ("Voice Log", "mic"),
        ("Scan Food", "barcode.viewfinder")
    ]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .frame(width: 36, height: 2)
                .foregroundColor(Color("grabber"))
                .padding(.top, 12)
            
            Text("New")
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 24)
                .padding(.bottom, 8)
            
            Divider()
            
            ForEach(options, id: \.0) { option in
                HStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: option.1)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 30)
                            .padding(.leading)
                        
                        Text(option.0)
                            .font(.system(size: 15))
                            .padding(.vertical, 16)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                }
                .background(Color(.systemBackground))
                .onTapGesture {
                    // Handle tap
                    switch option.0 {
                      case "Pod":
                          isPresented = false  
                          showQuickPodView = true
                      case "Log Food":
                        isPresented = false
                        viewModel.showFoodContainer()
                      default:
                          break
                      }
                }
                
                if option.0 != options.last?.0 {
                    Divider()
                        .frame(height: 0.5)
                        .padding(.leading, 65)
                        .opacity(0.5)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 0)
    }
}
