//
//  MinimizedActivityView.swift
//  Pods
//
//  Created by Dimi Nunez on 12/29/24.
//

import SwiftUI

struct MinimizedActivityView: View {
    @ObservedObject private var activityState = ActivityState.shared
    let podTitle: String
    @State private var showCancelAlert = false
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            
            HStack {
                Button(action: {
                    showCancelAlert = true
                    
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(width: 30)

                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(podTitle)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(activityState.stopwatch.formattedTime)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 25)
                
                Spacer()
                
                Color.clear.frame(width: 30, height: 45)
            }
         
            .padding()
            
            Spacer()
        }
      
        
        .background(Color("iosbg"))
        .onTapGesture {
            withAnimation {
                activityState.sheetHeight = .large
            }
        }
        .alert("Are you sure?", isPresented: $showCancelAlert) {
            Button("Cancel Activity", role: .destructive) {
                activityState.cancelActivity()
                onDismiss()
            }
            Button("Continue Activity", role: .cancel) { }
        }
//        message: {
//            Text("Are you sure you want to cancel this activity? All progress will be lost.")
//        }
    }
}
