//
//  LogExistingView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct LogExistingView: View {
    @EnvironmentObject var allFlow: AllFlow

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
                    // HapticFeedback.generate() 
                    // This is the last step, so a real app might dismiss the flow here
                    // or navigate to a different part of the app.
                    // For now, we can call next() which won't do anything if it's the last step,
                    // or you could add specific logic to dismiss or complete.
                    // allFlow.next() 
                    print("AllFlow finished")
                    // Potentially dismiss the sheet: allFlow.dismiss() or similar via Environment.dismiss
                    HapticFeedback.generate()
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
