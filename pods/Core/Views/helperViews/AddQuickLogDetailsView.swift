//
//  AddQuickLogDetailsView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct AddQuickLogDetailsView: View {
    @EnvironmentObject var allFlow: AllFlow

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Tell Us About Your Food") // Title for this view
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("logfood4") // Image for this view
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 285)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            // Placeholder for specific content of AddQuickLogDetailsView
            Text("Add a name and nutrition details.")
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
struct AddQuickLogDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        AddQuickLogDetailsView()
            .environmentObject(AllFlow()) // Provide a dummy AllFlow for preview
    }
}
#endif
