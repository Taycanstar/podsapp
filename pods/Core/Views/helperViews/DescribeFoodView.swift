//
//  DescribeFoodView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct DescribeFoodView: View {
    @EnvironmentObject var foodFlow: FoodFlow

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Describe Your Food") // Title
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("food0") // Image
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 375)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            Text("Tell us about the food item you want to create in your personal database") // Placeholder text
                .font(.system(size: 18, weight: .regular))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)

            Spacer()

            VStack {
                Button(action: {
                    foodFlow.next()
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
struct DescribeFoodView_Previews: PreviewProvider {
    static var previews: some View {
        DescribeFoodView()
            .environmentObject(FoodFlow()) // Provide a dummy FoodFlow for preview
    }
}
#endif
