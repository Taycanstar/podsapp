//
//  GenerateLogView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct GenerateLogView: View {
    @EnvironmentObject var allFlow: AllFlow

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("AI-opening possibilities") // Title for this view
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("logfood") // Image for this view
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 285)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            // Placeholder for specific content of GenerateLogView
            Text("Generate macronutrients with AI to log your meal")
                .font(.system(size: 18, weight: .regular))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)

            Spacer()

            // Bottom Bar with Continue Button
            VStack {
                Button(action: {
                    // HapticFeedback.generate() 
                    allFlow.next()
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("bg").edgesIgnoringSafeArea(.all))
    }
}

#if DEBUG
struct GenerateLogView_Previews: PreviewProvider {
    static var previews: some View {
        GenerateLogView()
            .environmentObject(AllFlow()) // Provide a dummy AllFlow for preview
    }
}
#endif
