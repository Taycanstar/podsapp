//
//  ScanFoodHelper.swift
//  Pods
//
//  Created by Dimi Nunez on 5/26/25.
//

import SwiftUI

struct ScanFoodHelper: View {
    @EnvironmentObject var scanFlow: ScanFlow

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Capture Your Food") // Title
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("scan3") // Image
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 375)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            Text("Snap a photo to start logging your food.") // Placeholder text
                .font(.system(size: 18, weight: .regular))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)

            Spacer()

            VStack {
                Button(action: {
                    scanFlow.next()
                    HapticFeedback.generate() // Assuming HapticFeedback is available
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
struct ScanFoodHelper_Previews: PreviewProvider {
    static var previews: some View {
        ScanFoodHelper()
            .environmentObject(ScanFlow()) // Provide a dummy ScanFlow for preview
    }
}
#endif
