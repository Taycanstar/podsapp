//
//  NameFoodView.swift
//  Pods
//
//  Created by Dimi Nunez on 5/21/25.
//

import SwiftUI

struct NameFoodView: View {
    @EnvironmentObject var foodFlow: FoodFlow
    @Environment(\.dismiss) var dismiss // To dismiss the sheet when done

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Personalize Your Food") // Title
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal, 25)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .multilineTextAlignment(.center)

            Image("food3") // Image
                .resizable()
                .scaledToFit()
                .frame(width: 375, height: 400)
                .padding(.horizontal)
                .padding(.bottom, 30)
            
            Text("Name your food and add nutritional details") // Placeholder text
                .font(.system(size: 18, weight: .regular))
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)

            Spacer()

            VStack {
                Button(action: {
                    print("🔍 NameFoodView - Finish button tapped")
                    HapticFeedback.generate() // Assuming HapticFeedback is available
                    // Complete the flow - this will trigger the container to dismiss
                    foodFlow.completeFlow()
                }) {
                    Text("Finish")
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
struct NameFoodView_Previews: PreviewProvider {
    static var previews: some View {
        NameFoodView()
            .environmentObject(FoodFlow()) // Provide a dummy FoodFlow for preview
    }
}
#endif
