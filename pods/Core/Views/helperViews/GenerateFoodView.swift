//
//  GenerateFoodView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct GenerateFoodView: View {
    @EnvironmentObject var foodFlow: FoodFlow

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Food Magic with AI") // Title for this view
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("food1") // Image for this view
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 350)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            Text("Turn your food description into a ready to log food item with complete nutritional data") // Placeholder text
                .font(.system(size: 18, weight: .regular))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)

            Spacer()

            VStack {
                Button(action: {
                    foodFlow.next()
                    HapticFeedback.generate()
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
struct GenerateFoodView_Previews: PreviewProvider {
    static var previews: some View {
        GenerateFoodView()
            .environmentObject(FoodFlow()) // Provide a dummy FoodFlow for preview
    }
}
#endif
