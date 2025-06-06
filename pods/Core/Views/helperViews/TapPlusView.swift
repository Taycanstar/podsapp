//
//  TapPlusView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct TapPlusView: View {
    @EnvironmentObject var logFlow: LogFlow
    // Environment dismiss can be used if the container view that presents this flow is modal.
    // @Environment(\.dismiss) var dismissFlow 

    var body: some View {
        // The NavigationView is part of the container. This view provides its content.
        VStack(alignment: .center, spacing: 0) {
            Text("Easily track calories and macros")
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .multilineTextAlignment(.center) 

            

            Image("logfood") // Ensure "logfood" is in your Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 200) // Adjusted size for better presence
                .padding(.horizontal)

            Text("Tap on the plus button to start logging")
                .font(.system(size: 18, weight: .regular))
                          .padding(.horizontal, 30)
                .multilineTextAlignment(.center) // Centered for better balance under a centered image
        
          
            
            Spacer()
            // Spacer() // Another spacer to further push content up slightly

            // Bottom Bar with Continue Button (mimicking GenderView style)
            VStack {
                Button(action: {
                    HapticFeedback.generate() // Uncomment if you have HapticFeedback implemented
                    logFlow.next() 
                }) {
                    Text("Continue")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure VStack fills available space
        .background(Color("bg").edgesIgnoringSafeArea(.all)) // Use your app's background color
        // NavigationBar elements (back, progress) will be handled by LogFlowContainerView
    }
}

// Preview
#if DEBUG
struct TapPlusView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a container to properly preview the flow context
        NavigationView { // A simple NavigationView for previewing nav bar items context
            TapPlusView()
                .environmentObject(LogFlow()) // Provide a dummy LogFlow for preview
                // .navigationBarHidden(true) // Simulating container behavior
        }
    }
}
#endif
