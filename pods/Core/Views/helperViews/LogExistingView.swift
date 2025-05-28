//
//  LogExistingView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct LogExistingView: View {
    @EnvironmentObject var allFlow: AllFlow
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Pick From Your Favorites") // Title for this view
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("logfood5") // Image for this view
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 285)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            // Placeholder for specific content of LogExistingView
            Text("Log existing food with the + button")
                .font(.system(size: 18, weight: .regular))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)

            Spacer()

            // Bottom Bar with Continue Button
            VStack {
                Button(action: {
                    print("🔍 LogExistingView - Finish button tapped")
                    HapticFeedback.generate()
                    // Complete the flow - this will trigger the container to dismiss
                    allFlow.completeFlow()
                }) {
                    Text("Finish") // Button text for the last step
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color("background"))
                        .foregroundColor(Color("bg"))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .padding(.bottom, 24)
            .background(Material.ultraThin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("bg").edgesIgnoringSafeArea(.all))
    }
}

#if DEBUG
struct LogExistingView_Previews: PreviewProvider {
    static var previews: some View {
        LogExistingView()
            .environmentObject(AllFlow()) // Provide a dummy AllFlow for preview
    }
}
#endif
